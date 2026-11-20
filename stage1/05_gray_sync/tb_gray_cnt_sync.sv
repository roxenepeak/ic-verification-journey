// tb_gray_cnt_sync.sv：bin2gray / gray2bin / gray_cnt_sync 的自检查 testbench
// 用法（在 WSL 中执行）：
//   cd /mnt/e/ic_verif/stage1/05_gray_sync && cmd.exe /c run.bat tb_gray_cnt_sync 123
// 第 2 个参数是随机种子，tb 里用 +seed=N 读入
// 分两部分：
//   第一部分：单独测转换模块（不涉及跨时钟域）
//   第二部分：同时例化两个 gray_cnt_sync，一个快时钟 → 慢时钟，一个慢时钟 → 快时钟
`timescale 1ns / 1ps
module tb_gray_cnt_sync;

  localparam real T_FAST = 10.0;  // 快时钟周期（ns）
  localparam real T_SLOW = 27.0;  // 慢时钟周期（ns），故意不是快时钟的整数倍
  localparam int  W      = 4;     // 计数器位宽（位宽小，回绕更频繁）

  // ---------------- 第一部分：转换模块 ----------------
  logic [W-1:0] b2g_bin, b2g_gray;
  logic [W-1:0] g2b_gray, g2b_bin;

  bin2gray #(.W(W)) u_bin2gray (.bin(b2g_bin),  .gray(b2g_gray));
  gray2bin #(.W(W)) u_gray2bin (.gray(g2b_gray), .bin(g2b_bin));
  
  // W=4 时手算的格雷码表：下标是二进制值，内容是对应的格雷码
  logic trans_is_error = 0;//记录转换模块是否错误
  logic [W-1:0] grayTable [16] = '{4'b0000,4'b0001,4'b0011,4'b0010,
                                   4'b0110,4'b0111,4'b0101,4'b0100,
                                   4'b1100,4'b1101,4'b1111,4'b1110,
                                   4'b1010,4'b1011,4'b1001,4'b1000};

  // ---------------- 第二部分：跨时钟域 ----------------
  logic clk_fast, clk_slow;
  logic rst_fast, rst_slow;

  // 方向 1：快 → 慢
  logic         inc_f2s;
  logic [W-1:0] cnt_a_f2s, cnt_b_f2s;
  logic [W-1:0] pre_cnt_a_f2s;//记录上一拍的cnt_a
  logic [W-1:0] pre_cnt_b_f2s;//记录上一拍的cnt_b
  int           b_change_cnt_f2s=0;//记录cnt_b的变化次数
  int           max_jump_cnt=0;//统计最多跳过值的次数（快到慢独有）
  // 方向 2：慢 → 快
  logic         inc_s2f;
  logic [W-1:0] cnt_a_s2f, cnt_b_s2f;
  logic [W-1:0] pre_cnt_a_s2f;

  logic [W-1:0] pre_cnt_b_s2f;
  int           b_change_cnt_s2f=0;
  //其他参数
  int error_cnt_f2s=0,error_cnt_s2f=0;//错误次数
  int fd;

  gray_cnt_sync #(.W(W)) dut_f2s (
    .clk_a(clk_fast), .rst_a(rst_fast), .inc(inc_f2s), .cnt_a(cnt_a_f2s),
    .clk_b(clk_slow), .rst_b(rst_slow), .cnt_b(cnt_b_f2s)
  );

  gray_cnt_sync #(.W(W)) dut_s2f (
    .clk_a(clk_slow), .rst_a(rst_slow), .inc(inc_s2f), .cnt_a(cnt_a_s2f),
    .clk_b(clk_fast), .rst_b(rst_fast), .cnt_b(cnt_b_s2f)
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

  // TODO：检查 cnt_a（每个方向）：每拍要么不变，要么正好加 1（含回绕），和 inc 一致
  //快到慢
  always @(posedge clk_fast) begin
    if(rst_fast) begin 
      pre_cnt_a_f2s<=0;
    end
    else begin
      //存储当前拍的数据
      if(inc_f2s) begin 
        pre_cnt_a_f2s<=cnt_a_f2s+1;
      end
      else pre_cnt_a_f2s<=cnt_a_f2s;
      //判断上一拍的数据是否出错
      //pre_cnt_a_f2s就是这一拍还没变化的cnt_a_f2s
      if(pre_cnt_a_f2s!==cnt_a_f2s) error_cnt_f2s++; 
    end
  end
  //慢到快
  always @(posedge clk_slow) begin
    if(rst_slow) begin 
      pre_cnt_a_s2f<=0;
    end
    else begin
      if(inc_s2f) begin
        pre_cnt_a_s2f<=cnt_a_s2f+1;
      end
      else pre_cnt_a_s2f<=cnt_a_s2f;
      //判断上一拍的数据是否出错
      if(pre_cnt_a_s2f!==cnt_a_s2f) error_cnt_s2f++;
    end
  end

  // TODO：检查 cnt_b（每个方向，在目的时钟沿检查）：
  //   - cnt_b 不能倒退，也不能跑到 cnt_a 前面
  //   - 慢 → 快方向：cnt_b 每拍最多变 1，不能跳过任何值
  //   - 快 → 慢方向：允许跳过中间值；统计一次最多跳了几个
  //   - 统计两个方向 cnt_b 变化的次数
  //快到慢
  always @(posedge clk_slow) begin 
    if(rst_slow) begin
      pre_cnt_b_f2s<=0;
    end
    else begin
      pre_cnt_b_f2s<=cnt_b_f2s;
      if(pre_cnt_b_f2s!==cnt_b_f2s) begin
        b_change_cnt_f2s++;
        //快到慢可以跳过中间值，每次变化不一定是1；只需检查两点：b没有跑到a前面（b落后a不超过12），b没有倒退（一个慢周期最多前进3）
        //注意右边的常数不能直接写12和3（32位），否则左边的减法会按32位计算，回绕时结果错误；写成4'd12、4'd3后按4位计算，自动按16取模（也可以把左边写成W'(...)）
        if(cnt_a_f2s-cnt_b_f2s>4'd12||cnt_b_f2s-pre_cnt_b_f2s>4'd3)
          error_cnt_f2s++;
        //b这一步前进了几个（W位差值，回绕也对），减1就是这一步跳过了几个值，取最大值
        if(W'(cnt_b_f2s-pre_cnt_b_f2s)-1>max_jump_cnt) max_jump_cnt=W'(cnt_b_f2s-pre_cnt_b_f2s)-1;
      end
    end
  end
  //慢到快
  always @(posedge clk_fast) begin
    if(rst_fast) begin 
      pre_cnt_b_s2f<=0;
    end
    else begin
      pre_cnt_b_s2f<=cnt_b_s2f;
      if(pre_cnt_b_s2f!==cnt_b_s2f) begin
        b_change_cnt_s2f++;
        if(W'(cnt_b_s2f-pre_cnt_b_s2f)!==1||W'(cnt_a_s2f-cnt_b_s2f)>3) 
          error_cnt_s2f++;//每次只能前进1；b落后a不超过3
      end
    end
  end

  initial begin
    int i;
    // TODO：从 +seed=N 读入种子（不传用默认值）并打印；打开 sim_result.txt（追加）
    int seed = 1;
    $value$plusargs("seed=%0d",seed);
    $display("seed=%0d",seed);
    process::self.srandom(seed);
    fd = $fopen("sim_result.txt","a");
    if(fd==0) $fatal(1,"sim_result.txt打开失败");
    // ---------------- 第一部分：转换模块 ----------------
    // TODO：遍历 W 位所有值：
    //   - bin2gray 的结果和手算的格雷码表一致（W=4 的 16 个值）
    //   - 相邻两个值（包括最大值回到 0）的格雷码只差 1 位
    for(i=0;i<16;i++) begin 
      //先测试二进制转格雷码模块
      b2g_bin=i;
      #1;//每次修改输入后记得#1
      if(b2g_gray!==grayTable[i]) trans_is_error=1'b1;//二进制转格雷码模块错误
      //测试格雷码转二进制模块
      g2b_gray=grayTable[i];
      #1;
      if(g2b_bin!==i) trans_is_error=1'b1;//格雷码转二进制模块错误
      //不用测试相邻两个值的格雷码只差1位，因为我的手算表已经满足了，只要没出错是肯定只差1位的
    end


    // ---------------- 第二部分：跨时钟域 ----------------
    // TODO：两个时钟域分别复位，检查复位后 cnt_a=0、cnt_b=0
    rst_fast=1'b1;rst_slow=1'b1;inc_f2s=1'b0;inc_s2f=1'b0;
    fork
      repeat(2) @(posedge clk_fast);
      repeat(2) @(posedge clk_slow);
    join
    if(cnt_a_f2s||cnt_b_f2s) error_cnt_f2s++;
    if(cnt_a_s2f||cnt_b_s2f) error_cnt_s2f++;
    fork
      begin @(negedge clk_fast); rst_fast=1'b0;end
      begin @(negedge clk_slow); rst_slow=1'b0;end
    join
    // TODO：场景 1：每个方向只加 1 次，cnt_b 最终等于 1
    fork
      //每个方向只加1次，记得inc清零，inc清零不能重新写一个fork-join，会导致inc_f2s持续多拍
      begin @(negedge clk_fast); rst_fast=1'b0;inc_f2s=1'b1; @(negedge clk_fast); inc_f2s=1'b0;end
      begin @(negedge clk_slow); rst_slow=1'b0;inc_s2f=1'b1; @(negedge clk_slow); inc_s2f=1'b0;end
    join
    repeat(10) @(posedge clk_slow);//等待数据传递到b
    if(cnt_b_f2s!==1||cnt_b_f2s!==cnt_a_f2s) error_cnt_f2s++;
    if(cnt_b_s2f!==1||cnt_b_s2f!==cnt_a_s2f) error_cnt_s2f++;
    // TODO：场景 2：每个方向连续每拍都加，至少回绕 2 圈
    fork
      begin @(negedge clk_fast); rst_fast=1'b0;inc_f2s=1'b1; repeat(40) @(negedge clk_fast); inc_f2s=1'b0;end
      begin @(negedge clk_slow); rst_slow=1'b0;inc_s2f=1'b1; repeat(40) @(negedge clk_slow); inc_s2f=1'b0;end
    join
    repeat(10) @(posedge clk_slow);
    if(cnt_b_f2s!==cnt_a_f2s) error_cnt_f2s++;
    if(cnt_b_s2f!==cnt_a_s2f) error_cnt_s2f++;
    // TODO：场景 3：随机给 inc（几百拍）
    fork
      begin 
        repeat(400) begin @(negedge clk_fast);inc_f2s=$urandom();end @(negedge clk_fast);inc_f2s=1'b0;
      end
      begin 
        repeat(400) begin @(negedge clk_slow);inc_s2f=$urandom();end @(negedge clk_slow);inc_s2f=1'b0;
      end
    join
    // TODO：场景结束后：停止 inc，等几个目的时钟周期，检查 cnt_b == cnt_a
    repeat(10) @(posedge clk_slow);
    if(cnt_b_f2s!==cnt_a_f2s) error_cnt_f2s++;
    if(cnt_b_s2f!==cnt_a_s2f) error_cnt_s2f++;
    // ---------------- 汇总 ----------------
    // TODO：打印并写进日志：种子和统计；格式和 04 一致（一行，逗号分隔）
        if(trans_is_error||error_cnt_f2s||error_cnt_s2f) begin
      $display("ERROR seed:%0d,transErr:%0b,f2sErrCnt:%0d,s2fErrCnt:%0d,f2sBChange:%0d,s2fBChange:%0d,f2sMaxJump:%0d",
               seed,trans_is_error,error_cnt_f2s,error_cnt_s2f,b_change_cnt_f2s,b_change_cnt_s2f,max_jump_cnt);
      $fdisplay(fd,"ERROR seed:%0d,transErr:%0b,f2sErrCnt:%0d,s2fErrCnt:%0d,f2sBChange:%0d,s2fBChange:%0d,f2sMaxJump:%0d",
               seed,trans_is_error,error_cnt_f2s,error_cnt_s2f,b_change_cnt_f2s,b_change_cnt_s2f,max_jump_cnt);
    end
    else begin
      $display("PASS seed:%0d,f2sBChange:%0d,s2fBChange:%0d,f2sMaxJump:%0d",
               seed,b_change_cnt_f2s,b_change_cnt_s2f,max_jump_cnt);
      $fdisplay(fd,"PASS seed:%0d,f2sBChange:%0d,s2fBChange:%0d,f2sMaxJump:%0d",
               seed,b_change_cnt_f2s,b_change_cnt_s2f,max_jump_cnt);
    end
    $fclose(fd);
    $finish;
  end

endmodule
