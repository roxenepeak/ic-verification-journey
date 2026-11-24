// tb_async_fifo.sv：async_fifo 的自检查 testbench
// 用法（在 WSL 中执行）：
//   cd /mnt/e/ic_verif/stage1/06_async_fifo && cmd.exe /c run.bat tb_async_fifo 123
// 第 2 个参数是随机种子，tb 里用 +seed=N 读入
// 同时例化两个 async_fifo：
//   dut_f2s：快时钟写、慢时钟读（写比读快，容易写满）
//   dut_s2f：慢时钟写、快时钟读（读比写快，容易读空）
`timescale 1ns / 1ps
module tb_async_fifo;

  localparam real T_FAST    = 10.0;   // 快时钟周期（ns）
  localparam real T_SLOW    = 27.0;   // 慢时钟周期（ns），故意不是快时钟的整数倍
  localparam int  DW        = 8;
  localparam int  AW        = 4;
  localparam int  DEPTH     = 1 << AW;
  localparam int  TRANS_NUM = 10000;  // 随机阶段每个方向至少成功传输的数据个数

  logic clk_fast, clk_slow;
  logic rst_fast, rst_slow;

  // 方向 1：快写慢读
  logic          wr_en_f2s, rd_en_f2s;
  logic [DW-1:0] wdata_f2s, rdata_f2s;
  logic          full_f2s,  empty_f2s;
  int success_wcnt_f2s = 0;//写成功的次数
  int refuse_wcnt_f2s = 0;//满时写被拒的次数
  int success_rcnt_f2s = 0;//读成功的次数
  int refuse_rcnt_f2s = 0;//空时读被拒的次数
  int full_cnt_f2s = 0;//假满的次数
  int empty_cnt_f2s = 0;//假空的次数
  // 方向 2：慢写快读
  logic          wr_en_s2f, rd_en_s2f;
  logic [DW-1:0] wdata_s2f, rdata_s2f;
  logic          full_s2f,  empty_s2f;
  int success_wcnt_s2f = 0;
  int refuse_wcnt_s2f = 0;
  int success_rcnt_s2f = 0;
  int refuse_rcnt_s2f = 0;
  int full_cnt_s2f = 0;
  int empty_cnt_s2f = 0;

  //其他信号
  int error_cnt_f2s=0;
  int error_cnt_s2f=0;
  int fd;

  async_fifo #(.DW(DW), .AW(AW)) dut_f2s (
    .wclk(clk_fast), .wrst(rst_fast), .wr_en(wr_en_f2s), .wdata(wdata_f2s), .full(full_f2s),
    .rclk(clk_slow), .rrst(rst_slow), .rd_en(rd_en_f2s), .rdata(rdata_f2s), .empty(empty_f2s)
  );

  async_fifo #(.DW(DW), .AW(AW)) dut_s2f (
    .wclk(clk_slow), .wrst(rst_slow), .wr_en(wr_en_s2f), .wdata(wdata_s2f), .full(full_s2f),
    .rclk(clk_fast), .rrst(rst_fast), .rd_en(rd_en_s2f), .rdata(rdata_s2f), .empty(empty_s2f)
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

  // TODO：两个方向各自的记分板（按顺序记录已写入、还没读出的数据）
  //其实就是存储数据的队列（不用检查延迟不需要时间队列）
  logic [DW-1:0] data_fifo_f2s[$];
  logic [DW-1:0] data_fifo_s2f[$];


  // TODO：满、空标志检查（两个方向都要）：
  //       1. 记分板里正好有 DEPTH 个数据时 full 必须为 1；记分板为空时 empty 必须为 1
  //       2. 记分板里的数据个数任何时候都不能超过 DEPTH
  //       3. 统计假满、假空出现的次数（只统计，不报错）
  //这个检查写在监视器中
  // TODO：写端监视：在写时钟沿采样，统计写成功次数、满时被拒次数
  //快时钟为写端
  always @(posedge clk_fast) begin
    //这三个情况都要写在写监视器
    //且需要写在开头，表示先检查在push/pop，如果写在结尾队列已经更新了但是dut还没有更新，会出现full_f2s误报的情况（size==DEPTH但是full_f2s!=1）
    //可以再写四个always块再下降沿等待dut更新后检查，这个always块只用于更新记分板
    if(data_fifo_f2s.size()==DEPTH && full_f2s !== 1) error_cnt_f2s++; 
    if(data_fifo_f2s.size()>DEPTH) error_cnt_f2s++;//计分板中的数据个数不能超过DEPTH
    if(full_f2s===1&&data_fifo_f2s.size()<DEPTH) full_cnt_f2s++;//统计假满的次数(不是真满)
    if(wr_en_f2s===1) begin//需要写入
      if(full_f2s!==1) begin//判断是否满
        data_fifo_f2s.push_back(wdata_f2s);
        success_wcnt_f2s++;
      end
      else begin 
        refuse_wcnt_f2s++;
      end
    end
  end
  //慢时钟为写端
  always @(posedge clk_slow) begin 
    if(data_fifo_s2f.size()==DEPTH && full_s2f!==1) error_cnt_s2f++;
    if(data_fifo_s2f.size()>DEPTH) error_cnt_s2f++;
    if(full_s2f===1&&data_fifo_s2f.size()<DEPTH) full_cnt_s2f++;
    if(wr_en_s2f===1) begin 
      if(full_s2f!==1) begin 
        data_fifo_s2f.push_back(wdata_s2f);
        success_wcnt_s2f++;
      end
      else begin 
        refuse_wcnt_s2f++;
      end
    end 
  end

  // TODO：读端监视：在读时钟沿采样，读出的数据按顺序和记分板比对；
  //       统计读成功次数、空时被拒次数；没有可读的数据却读成功要报错
  //慢时钟为读端
  logic [DW-1:0] pre_data_f2s = 0;
  always @(posedge clk_slow) begin
    //这两种情况需要写在读监视器
    //和写监视器类似，需要写在开头，队列更新了，但是dut可能还没有更新
    if(!rst_slow&&  data_fifo_f2s.size()===0&&empty_f2s!==1) error_cnt_f2s++;
    if(empty_f2s===1&&data_fifo_f2s.size()>0) empty_cnt_f2s++;//统计假空的次数(不是真空)
    if(rd_en_f2s===1) begin
      if(empty_f2s!==1) begin
        if(data_fifo_f2s.size()===0) error_cnt_f2s++;//没有可读的数据却读成功
        else success_rcnt_f2s++;
        //在这个上升沿的时候rdata还没有读出，还是上个周期的rdata，所以需要用上一次读出的fifo数据去比较
        //这样处理最后一个rdata没有比较到，所以需要在initial块中单独比较
        if(pre_data_f2s!==rdata_f2s) error_cnt_f2s++;//对比读出的数据
        pre_data_f2s = data_fifo_f2s.pop_front();
      end
      else begin 
        refuse_rcnt_f2s++;
      end
    end
  end
  //快时钟为读端
  logic [DW-1:0] pre_data_s2f = 0;
  always @(posedge clk_fast) begin 
    if(!rst_fast&&data_fifo_s2f.size()===0&&empty_s2f!==1) error_cnt_s2f++;
    if(empty_s2f===1&&data_fifo_s2f.size()>0) empty_cnt_s2f++;
    if(rd_en_s2f===1) begin 
      if(empty_s2f!==1) begin 
        if(data_fifo_s2f.size()===0) error_cnt_s2f++;else success_rcnt_s2f++;
        if(pre_data_s2f!==rdata_s2f) error_cnt_s2f++;
        pre_data_s2f = data_fifo_s2f.pop_front();
      end
      else begin 
        refuse_rcnt_s2f++;
      end
    end
  end

  // TODO：两个方向各自的写 task、读 task（在各自的时钟域驱动）
  //快写慢读
  //写
  task automatic write_f2s(logic wr_en=1'b1); 
    @(negedge clk_fast);
    rst_fast=1'b0;wr_en_f2s=wr_en;wdata_f2s=$urandom();
    @(posedge clk_fast) #1;//等到上升沿采样完成后拉低，既可以满足连续读取也可以满足非连续读取
    wr_en_f2s=1'b0;
  endtask
  //读
  task automatic read_f2s(logic rd_en=1'b1);
    @(negedge clk_slow);
    rst_slow=1'b0;rd_en_f2s=rd_en;
    @(posedge clk_slow) #1;
    rd_en_f2s=1'b0;
  endtask
  //快读慢写
  //写
  task automatic write_s2f(logic wr_en=1'b1);
    @(negedge clk_slow);
    rst_slow=1'b0;wr_en_s2f=wr_en;wdata_s2f=$urandom();
    @(posedge clk_slow) #1;
    wr_en_s2f=1'b0;
  endtask
  //读
  task automatic read_s2f(logic rd_en=1'b1);
    @(negedge clk_fast);
    rst_fast=1'b0;rd_en_s2f=rd_en;
    @(posedge clk_fast) #1;
    rd_en_s2f=1'b0;
  endtask

    //随机阶段的读写概率（%），按成功写入数每 1000 个换一段：写多读少 → 读多写少 → 一样多
  function automatic int wr_prob(int cnt);
    case((cnt/1000)%3)
      0: return 90;
      1: return 10;
      default: return 50;
    endcase
  endfunction
  function automatic int rd_prob(int cnt);
    case((cnt/1000)%3)
      0: return 10;
      1: return 90;
      default: return 50;
    endcase
  endfunction

  initial begin
    // TODO：从 +seed=N 读入种子（不传用默认值）并打印；打开 sim_result.txt（追加）
    int seed = 1;
    $value$plusargs("seed=%0d",seed);
    $display("seed=%0d",seed);
    process::self.srandom(seed);
    fd = $fopen("sim_result.txt","a");
    if(fd==0) $fatal(1,"sim_result.txt打开失败");

    // TODO：两个时钟域各自复位；复位后检查 full=0、empty=1、rdata=0
    rst_fast=1'b1;rst_slow=1'b1;wr_en_f2s=1'b0;rd_en_f2s=1'b0;wr_en_s2f=1'b0;rd_en_s2f=1'b0;
    fork
      repeat(2) @(posedge clk_fast);
      repeat(2) @(posedge clk_slow);
    join
    if(full_f2s!==0||empty_f2s!==1||rdata_f2s!==0) error_cnt_f2s++;
    if(full_s2f!==0||empty_s2f!==1||rdata_s2f!==0) error_cnt_s2f++;

    // TODO：定向场景（两个方向都要做）：
    //   1. 写 1 个、读 1 个
    fork
      begin write_f2s();wait(empty_f2s===0);read_f2s();end
      begin write_s2f();wait(empty_s2f===0);read_s2f();end
    join
    repeat(5) @(posedge clk_slow);//等待场景1完成
    if(empty_f2s!==1) error_cnt_f2s++;
    if(empty_s2f!==1) error_cnt_s2f++; 
    //   2. 一直写到 full=1，再继续写几个（应该被拒，数据不能进 FIFO）
    fork
      begin repeat(20) write_f2s();end
      begin repeat(20) write_s2f();end
    join
    repeat(5) @(posedge clk_slow);
    if(full_f2s!==1) error_cnt_f2s++;
    if(full_s2f!==1) error_cnt_s2f++;
    //   3. 一直读到 empty=1，再继续读几个（应该被拒）
    fork
      begin repeat(25) read_f2s();end
      begin repeat(25) read_s2f();end
    join
    repeat(5) @(posedge clk_slow);
    if(empty_f2s!==1) error_cnt_f2s++;
    if(empty_s2f!==1) error_cnt_s2f++; 
    //   4. 边写边读一段时间，让指针绕过至少两圈
    //   每个场景结束后：停止读写，等几个周期，检查 full / empty 恢复到真实状态
    //注意是是边读边写，读和写是同时进行的，读写需要是同一个fork的两条语句
    fork
      begin
      fork
        repeat(40) write_f2s();
        repeat(40) read_f2s();
      join
      end
      begin 
      fork
        repeat(40) write_s2f();
        repeat(40) read_s2f();
      join
      end
    join
    repeat(5) @(posedge clk_slow);
    if(full_f2s!==(data_fifo_f2s.size()==DEPTH) || empty_f2s!==(data_fifo_f2s.size()==0)) error_cnt_f2s++;
    if(full_s2f!==(data_fifo_s2f.size()==DEPTH) || empty_s2f!==(data_fifo_s2f.size()==0)) error_cnt_s2f++;
    
    // TODO：随机场景：每个方向至少成功传输 TRANS_NUM 个数据；
    //       wr_en、rd_en 的概率要分几段变化，保证写满、读空都出现过很多次
    fork
      begin
        fork
            //成功读写1000次后就更换读写的概率
            while(success_wcnt_f2s<TRANS_NUM) write_f2s($urandom_range(0,99)<wr_prob(success_wcnt_f2s));
            while(success_rcnt_f2s<TRANS_NUM) read_f2s($urandom_range(0,99)<rd_prob(success_wcnt_f2s));
        join
      end
      begin
        fork
            while(success_wcnt_s2f<TRANS_NUM) write_s2f($urandom_range(0,99)<wr_prob(success_wcnt_s2f));
            while(success_rcnt_s2f<TRANS_NUM) read_s2f($urandom_range(0,99)<rd_prob(success_wcnt_s2f));
        join
      end
    join
    repeat(5) @(posedge clk_slow);
    // TODO：结束前停止读写，把 FIFO 读空，检查记分板为空
    repeat(20) begin 
      read_f2s();
      read_s2f();
    end
    repeat(5) @(posedge clk_slow);
    if(data_fifo_f2s.size()!==0) error_cnt_f2s++;
    if(data_fifo_s2f.size()!==0) error_cnt_s2f++;
    //处理dut和记分板在读监视器不同步的收尾问题
    if(pre_data_f2s!==rdata_f2s) error_cnt_f2s++;
    if(pre_data_s2f!==rdata_s2f) error_cnt_s2f++;

    // TODO：汇总：屏幕和 sim_result.txt 各打印一行（格式和 02～05 一致，逗号分隔）
    //       没有错误打印 PASS 行，有错误打印 ERROR 行
    // 字段含义：WrOk/WrRefuse = 写成功/满时被拒，RdOk/RdRefuse = 读成功/空时被拒，
    //           FalseFull/FalseEmpty = 假满/假空的拍数
    if(error_cnt_f2s||error_cnt_s2f) begin
      $display("ERROR seed:%0d,f2sErrCnt:%0d,s2fErrCnt:%0d,f2sWrOk:%0d,f2sWrRefuse:%0d,f2sRdOk:%0d,f2sRdRefuse:%0d,f2sFalseFull:%0d,f2sFalseEmpty:%0d,s2fWrOk:%0d,s2fWrRefuse:%0d,s2fRdOk:%0d,s2fRdRefuse:%0d,s2fFalseFull:%0d,s2fFalseEmpty:%0d",
               seed,error_cnt_f2s,error_cnt_s2f,
               success_wcnt_f2s,refuse_wcnt_f2s,success_rcnt_f2s,refuse_rcnt_f2s,full_cnt_f2s,empty_cnt_f2s,
               success_wcnt_s2f,refuse_wcnt_s2f,success_rcnt_s2f,refuse_rcnt_s2f,full_cnt_s2f,empty_cnt_s2f);
      $fdisplay(fd,"ERROR seed:%0d,f2sErrCnt:%0d,s2fErrCnt:%0d,f2sWrOk:%0d,f2sWrRefuse:%0d,f2sRdOk:%0d,f2sRdRefuse:%0d,f2sFalseFull:%0d,f2sFalseEmpty:%0d,s2fWrOk:%0d,s2fWrRefuse:%0d,s2fRdOk:%0d,s2fRdRefuse:%0d,s2fFalseFull:%0d,s2fFalseEmpty:%0d",
               seed,error_cnt_f2s,error_cnt_s2f,
               success_wcnt_f2s,refuse_wcnt_f2s,success_rcnt_f2s,refuse_rcnt_f2s,full_cnt_f2s,empty_cnt_f2s,
               success_wcnt_s2f,refuse_wcnt_s2f,success_rcnt_s2f,refuse_rcnt_s2f,full_cnt_s2f,empty_cnt_s2f);
    end
    else begin
      $display("PASS seed:%0d,f2sWrOk:%0d,f2sWrRefuse:%0d,f2sRdOk:%0d,f2sRdRefuse:%0d,f2sFalseFull:%0d,f2sFalseEmpty:%0d,s2fWrOk:%0d,s2fWrRefuse:%0d,s2fRdOk:%0d,s2fRdRefuse:%0d,s2fFalseFull:%0d,s2fFalseEmpty:%0d",
               seed,
               success_wcnt_f2s,refuse_wcnt_f2s,success_rcnt_f2s,refuse_rcnt_f2s,full_cnt_f2s,empty_cnt_f2s,
               success_wcnt_s2f,refuse_wcnt_s2f,success_rcnt_s2f,refuse_rcnt_s2f,full_cnt_s2f,empty_cnt_s2f);
      $fdisplay(fd,"PASS seed:%0d,f2sWrOk:%0d,f2sWrRefuse:%0d,f2sRdOk:%0d,f2sRdRefuse:%0d,f2sFalseFull:%0d,f2sFalseEmpty:%0d,s2fWrOk:%0d,s2fWrRefuse:%0d,s2fRdOk:%0d,s2fRdRefuse:%0d,s2fFalseFull:%0d,s2fFalseEmpty:%0d",
               seed,
               success_wcnt_f2s,refuse_wcnt_f2s,success_rcnt_f2s,refuse_rcnt_f2s,full_cnt_f2s,empty_cnt_f2s,
               success_wcnt_s2f,refuse_wcnt_s2f,success_rcnt_s2f,refuse_rcnt_s2f,full_cnt_s2f,empty_cnt_s2f);
    end
    $fclose(fd);
    $finish;
  end
endmodule
