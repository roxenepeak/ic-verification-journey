// tb_handshake_sync.sv：handshake_sync 的自检查 testbench
// 用法（在 WSL 中执行）：
//   cd /mnt/e/ic_verif/stage1/04_handshake_sync && cmd.exe /c run.bat tb_handshake_sync 123
// 第 2 个参数是随机种子，tb 里用 +seed=N 读入
// 同时例化两个 handshake_sync：一个快时钟 → 慢时钟，一个慢时钟 → 快时钟，两个方向一起测
`timescale 1ns / 1ps
module tb_handshake_sync;

  localparam real T_FAST = 10.0;  // 快时钟周期（ns）
  localparam real T_SLOW = 27.0;  // 慢时钟周期（ns），故意不是快时钟的整数倍
  localparam int  DW     = 8;     // 数据位宽

  logic clk_fast, clk_slow;
  logic rst_fast, rst_slow;

  // 方向 1：快 → 慢
  logic          src_valid_f2s, src_ready_f2s, dst_valid_f2s;
  logic [DW-1:0] src_data_f2s, dst_data_f2s;
  real f2s_time_fifo[$];//记录发送数据有效的时间戳队列，方便得到延时
  logic [DW-1:0] f2s_data_fifo[$];//记录发送数据的队列，方便与接收数据对比是否相同
  int f2s_send_cnt,f2s_receive_cnt;//统计发送和接收数据的次数
  real f2s_maxlat = 0,f2s_minlat=1e9;//发送接收的最大延时和最小延时
  logic pre_dst_valid_f2s;//记录接收端数据上一拍是否有效
  logic [DW-1:0] fifo_front_data_f2s;//数据队列的队头数据
  real fifo_front_time_f2s;//时间队列的对头数据
  // 方向 2：慢 → 快
  logic          src_valid_s2f, src_ready_s2f, dst_valid_s2f;
  logic [DW-1:0] src_data_s2f, dst_data_s2f;
  real s2f_time_fifo[$];
  logic [DW-1:0] s2f_data_fifo[$];
  int s2f_send_cnt,s2f_receive_cnt;
  real s2f_maxlat = 0,s2f_minlat=1e9;
  logic pre_dst_valid_s2f;
  logic [DW-1:0] fifo_front_data_s2f;
  real fifo_front_time_s2f;
  //文件句柄和两个方向是否出错
  int fd;
  logic f2s_is_error=0,s2f_is_error=0;

  handshake_sync #(.DW(DW)) dut_f2s (
    .clk_a    (clk_fast),
    .rst_a    (rst_fast),
    .src_valid(src_valid_f2s),
    .src_data (src_data_f2s),
    .src_ready(src_ready_f2s),
    .clk_b    (clk_slow),
    .rst_b    (rst_slow),
    .dst_valid(dst_valid_f2s),
    .dst_data (dst_data_f2s)
  );

  handshake_sync #(.DW(DW)) dut_s2f (
    .clk_a    (clk_slow),
    .rst_a    (rst_slow),
    .src_valid(src_valid_s2f),
    .src_data (src_data_s2f),
    .src_ready(src_ready_s2f),
    .clk_b    (clk_fast),
    .rst_b    (rst_fast),
    .dst_valid(dst_valid_s2f),
    .dst_data (dst_data_s2f)
  );

  // TODO：产生两个时钟（周期 T_FAST、T_SLOW）
  initial begin 
    clk_fast=0;
    forever #(T_FAST/2) clk_fast=~clk_fast;
  end
  initial begin
    clk_slow=0;
    forever #(T_SLOW/2) clk_slow=~clk_slow;
  end

  // TODO：输入监视器（每个方向一个）：记录每个被接收的发送（src_valid && src_ready），计数
  //快到慢
  always@(posedge clk_fast) begin
    if(!rst_fast) begin
      if(src_valid_f2s&&src_ready_f2s) begin
        f2s_time_fifo.push_back($realtime);
        f2s_data_fifo.push_back(src_data_f2s);
        f2s_send_cnt++;
      end
    end
  end
  //慢到快
  always@(posedge clk_slow) begin
    if(!rst_slow) begin
      if(src_valid_s2f&&src_ready_s2f) begin
        s2f_time_fifo.push_back($realtime);
        s2f_data_fifo.push_back(src_data_s2f);
        s2f_send_cnt++;
      end
    end
  end

  // TODO：输出监视器（每个方向一个）：
  //   - 每个 dst_valid 都要对上一个被接收的发送，dst_data 和发送的数据一致，顺序一致
  //   - dst_valid 宽度正好 1 个目的时钟周期
  //   - 没有发送却出现 dst_valid 要报错
  //   - 统计接收个数、传输延迟（最小/最大）
  //快到慢
  always @(posedge clk_slow) begin 
    if(rst_slow) pre_dst_valid_f2s<=1'b0;//记得复位
    else pre_dst_valid_f2s<=dst_valid_f2s;
    if(dst_valid_f2s) begin//如果当前拍有被接收的数据，则需要处理
      f2s_receive_cnt++;//统计接收个数
      if(pre_dst_valid_f2s) f2s_is_error = 1'b1;//如果上一拍和当前拍都为1则表示出错了
      if(f2s_time_fifo.size() || f2s_data_fifo.size()) begin 
        fifo_front_data_f2s=f2s_data_fifo.pop_front();
        fifo_front_time_f2s=f2s_time_fifo.pop_front();
        //如果和当前接收数据不同则报错
        if(fifo_front_data_f2s!==dst_data_f2s) f2s_is_error=1'b1;
        //计算最大延时和最小延时
        f2s_maxlat = (($realtime-fifo_front_time_f2s)>f2s_maxlat) ? ($realtime-fifo_front_time_f2s) : f2s_maxlat;
        f2s_minlat = (($realtime-fifo_front_time_f2s)<f2s_minlat) ? ($realtime-fifo_front_time_f2s) : f2s_minlat;
      end
      else f2s_is_error=1'b1;//如果有被接收的数据但是没有发送（队列为空）则报错
    end
  end
  //慢到快
  always @(posedge clk_fast) begin 
    if(rst_fast) pre_dst_valid_s2f<=1'b0;
    else pre_dst_valid_s2f<=dst_valid_s2f;//存储上一拍的数据有效信号
    if(dst_valid_s2f) begin//如果当前拍有被接收的数据，则需要处理
      s2f_receive_cnt++;//统计接收个数
      if(pre_dst_valid_s2f) s2f_is_error = 1'b1;//如果上一拍和当前拍都为1则表示出错了
      if(s2f_time_fifo.size() || s2f_data_fifo.size()) begin 
        fifo_front_data_s2f=s2f_data_fifo.pop_front();
        fifo_front_time_s2f=s2f_time_fifo.pop_front();
        //如果和当前接收数据不同则报错
        if(fifo_front_data_s2f!== dst_data_s2f) s2f_is_error=1'b1;
        //计算最大延时和最小延时
        s2f_maxlat = (($realtime-fifo_front_time_s2f)>s2f_maxlat) ? ($realtime-fifo_front_time_s2f) : s2f_maxlat;
        s2f_minlat = (($realtime-fifo_front_time_s2f)<s2f_minlat) ? ($realtime-fifo_front_time_s2f) : s2f_minlat;
      end
      else s2f_is_error=1'b1;//如果有被接收的数据但是没有发送（队列为空）则报错
    end
  end

  // TODO：检查：每个方向发送个数 = 接收个数；每次传输结束后 src_ready 能回到 1（不能卡死）
  task automatic check();
    //每个场景都需要检查，虽然计数个数是所有场景共用的，但是我为了方便一点还是每次都检查了
    //如果想每个场景单独检查计数个数需要每次开始新的场景的时候将计数器清零
    if(f2s_send_cnt!==f2s_receive_cnt||src_ready_f2s!==1'b1) f2s_is_error = 1'b1;
    if(s2f_send_cnt!==s2f_receive_cnt||src_ready_s2f!==1'b1) s2f_is_error = 1'b1;
  endtask

  // TODO：发送 task（每个方向一个）：在源时钟域给出一个数据，按需要等待 src_ready
  //快到慢
  task automatic sent_f2s(logic[DW-1:0] data, bit waitReady=1);
    @(negedge clk_fast);
    if(waitReady) while(!src_ready_f2s) @(negedge clk_fast);//等到能接收数据的时候再发，为了不同的定向测试
    src_valid_f2s=1'b1;
    src_data_f2s=data;
    @(negedge clk_fast);//记得valid保持一拍后就置0
    src_valid_f2s=1'b0;
  endtask
  //慢到快
  task automatic sent_s2f(logic[DW-1:0] data,bit waitReady=1);
    @(negedge clk_slow);
    if(waitReady) while(!src_ready_s2f) @(negedge clk_slow);
    src_valid_s2f=1'b1;
    src_data_s2f=data;
    @(negedge clk_slow);
    src_valid_s2f=1'b0;
  endtask

  initial begin
    // TODO：从 +seed=N 读入种子（不传用默认值）并打印；打开 sim_result.txt（追加）
    int seed = 1;
    $value$plusargs("seed=%0d",seed);
    $display("seed=%0d",seed);
    process::self.srandom(seed);
    fd = $fopen("sim_result.txt","a");
    if(fd==0) $fatal(1,"sim_result.txt文件打开失败");
    // TODO：两个时钟域分别复位，检查复位后 src_ready=1、dst_valid=0、dst_data=0
    rst_fast=1'b1;rst_slow=1'b1;src_valid_f2s=0;src_data_f2s=0;src_valid_s2f=0;src_data_s2f=0;
    fork
      repeat(2) @(posedge clk_fast);
      repeat(2) @(posedge clk_slow);
    join
    if(src_ready_f2s!==1||dst_valid_f2s!==0||dst_data_f2s!==0) f2s_is_error = 1'b1;
    if(src_ready_s2f!==1||dst_valid_s2f!==0||dst_data_s2f!==0) s2f_is_error = 1'b1;
    fork
      begin @(negedge clk_fast);rst_fast=1'b0;end
      begin @(negedge clk_slow);rst_slow=1'b0;end
    join

    // ---------------- 定向测试 ----------------
    // TODO：场景 1：每个方向发 1 个数据，收到的数据正确、dst_valid 只出现 1 次
    fork
      sent_f2s($urandom());
      sent_s2f($urandom());
    join
    repeat(20) @(posedge clk_slow);//等待几个时钟周期，保证数据传输结束
    //检查dst_valid只出现过一次（数据传输结束后再检查）
    if(f2s_receive_cnt!=1) f2s_is_error=1'b1;
    if(s2f_receive_cnt!=1) s2f_is_error=1'b1; 
    check();
    // TODO：场景 2：每个方向连续发多个不同的数据（src_ready 一回到 1 就发下一个），全部按顺序收到
    fork
      repeat(10) sent_f2s($urandom());
      repeat(10) sent_s2f($urandom());
    join
    repeat(20) @(posedge clk_slow);
    //场景2发了十个数据，如果全部收到则当前的receive_cnt会比场景2之前的正好多10个
    if(f2s_receive_cnt!=11) f2s_is_error=1'b1;//场景1收到1个+场景2收到10个
    if(s2f_receive_cnt!=11) s2f_is_error=1'b1;

    check();
    // TODO：场景 3：传输进行中（src_ready=0）给 src_valid 和另一个数据，这个数据被忽略，只收到原来的数据
    fork
      begin sent_f2s($urandom()); sent_f2s($urandom(),0); end//正常发第一个，然后不等待ready信号发第二个，第二个会被忽略
      begin sent_s2f($urandom()); sent_s2f($urandom(),0); end
    join
    repeat(20) @(posedge clk_slow);
    //场景3发了两个数据，但是第二个数据会被忽略，所以当前的receive_cnt会比场景3之前的多1个而不是2个
    if(f2s_receive_cnt!=12) f2s_is_error=1'b1;//前面累计11个+场景3收到1个
    if(s2f_receive_cnt!=12) s2f_is_error=1'b1;
    check();
    // TODO：场景 4：长时间不发，dst_valid 一直为 0
    fork
      begin repeat(100) @(posedge clk_fast); if(dst_valid_f2s) f2s_is_error=1'b1;end
      begin repeat(100) @(posedge clk_slow); if(dst_valid_s2f) s2f_is_error=1'b1;end
    join
    repeat(20) @(posedge clk_slow);
    check();

    // ---------------- 随机测试 ----------------
    // TODO：两个方向各发几百个随机数据，发送之间的空闲时间随机；随机地在 src_ready=0 时给 src_valid（应被忽略）
    fork
      repeat(300) begin repeat($urandom_range(0,5)) @(negedge clk_fast); sent_f2s($urandom(),$urandom_range(0,1)); end//发送之间的空闲时间随机并随机等待或不等待ready信号
      repeat(300) begin repeat($urandom_range(0,5)) @(negedge clk_slow); sent_s2f($urandom(),$urandom_range(0,1)); end
    join
    repeat(20) @(posedge clk_slow);
    check();
    // ---------------- 汇总 ----------------
    // TODO：等最后一次传输完成后再统计；打印并写进日志：种子和统计；格式和 02_sync_fifo 一致（一行，逗号分隔）
    if(f2s_is_error||s2f_is_error) begin
      $display("ERROR seed:%0d,f2sIsError:%0b,s2fIsError:%0b,f2sSend:%0d,f2sRecv:%0d,f2sMaxlat:%.1f,f2sMinlat:%.1f,s2fSend:%0d,s2fRecv:%0d,s2fMaxlat:%.1f,s2fMinlat:%.1f",
               seed,f2s_is_error,s2f_is_error,f2s_send_cnt,f2s_receive_cnt,f2s_maxlat,f2s_minlat,s2f_send_cnt,s2f_receive_cnt,s2f_maxlat,s2f_minlat);
      $fdisplay(fd,"ERROR seed:%0d,f2sIsError:%0b,s2fIsError:%0b,f2sSend:%0d,f2sRecv:%0d,f2sMaxlat:%.1f,f2sMinlat:%.1f,s2fSend:%0d,s2fRecv:%0d,s2fMaxlat:%.1f,s2fMinlat:%.1f",
               seed,f2s_is_error,s2f_is_error,f2s_send_cnt,f2s_receive_cnt,f2s_maxlat,f2s_minlat,s2f_send_cnt,s2f_receive_cnt,s2f_maxlat,s2f_minlat);
    end
    else begin
      $display("PASS seed:%0d,f2sSend:%0d,f2sRecv:%0d,f2sMaxlat:%.1f,f2sMinlat:%.1f,s2fSend:%0d,s2fRecv:%0d,s2fMaxlat:%.1f,s2fMinlat:%.1f",
               seed,f2s_send_cnt,f2s_receive_cnt,f2s_maxlat,f2s_minlat,s2f_send_cnt,s2f_receive_cnt,s2f_maxlat,s2f_minlat);
      $fdisplay(fd,"PASS seed:%0d,f2sSend:%0d,f2sRecv:%0d,f2sMaxlat:%.1f,f2sMinlat:%.1f,s2fSend:%0d,s2fRecv:%0d,s2fMaxlat:%.1f,s2fMinlat:%.1f",
               seed,f2s_send_cnt,f2s_receive_cnt,f2s_maxlat,f2s_minlat,s2f_send_cnt,s2f_receive_cnt,s2f_maxlat,s2f_minlat);
    end
    $fclose(fd);
    $finish;
  end
endmodule
