// tb_seq1011_nolap.sv：“1011”序列检测器（不重叠版）的自检查 testbench
// 用法：run.bat tb_seq1011_nolap
module tb_seq1011_nolap;
  logic clk, rst, din;
  logic det;
  logic expDet;
  int errCnt=0,checkCnt=0,modelError=0,detNum=0;
  logic [3:0] hist;//用于存储输入序列
  logic expState,expNextState;
  // TODO：实例化 seq1011_nolap
  seq1011_nolap dut(.clk(clk),.rst(rst),.din(din),.det(det));

  // TODO：产生时钟，周期 10ns
  initial clk = 0;
  always #5 clk = ~clk;
  // ---------- 参考模型 ----------
  // TODO：产生期望的 det
  assign expDet = (hist==4'b1011);//直接判断输入的值是否满足条件
  always @(posedge clk) begin //用于存储输入的值
    if(rst)
      hist <= 4'b0;
    else if(expDet)//注意这里如果满足条件后需要重置前三位，否则会出现重叠检测的情况（1011011会检测到两次）
      hist<= {3'b000,din};
    else
      hist <= {hist[2:0],din};
  end


  // ---------- 检查 ----------
  // TODO：check task：
  //       1. DUT 和手算期望值比较，不一致打印 DUT ERROR（带时间、期望值、实际值）并计数
  //       2. 参考模型和手算期望值比较，不一致打印 MODEL ERROR（带时间、期望值、模型值）并计数
  //       3. 统计检查次数
  task automatic check(logic handExpDet);
    if(det!==handExpDet) begin
      $display("error time:%0t,expDet:%0d,det:%0d",$time,handExpDet,det);
      errCnt++;
    end
    if(handExpDet!==expDet) begin
      $display("model error");
      modelError++;
    end
    checkCnt++;
  endtask

  // ---------- 驱动 ----------
  // 要求：每段定向测试开头都把前提条件显式设好（先复位），不依赖上一段结束时的状态
  initial begin
    int i;
    // TODO：0 时刻初始化所有输入，复位，然后释放复位
    rst=1'b1;din=1'b0;
    repeat(2) @(posedge clk);
    @(negedge clk); 
    rst = 1'b0;
    // ---------- 定向 1：输入 1011，检测到 1 次 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<4;i++) begin 
      @(negedge clk);
      if(i==1) din=1'b0;
      else din=1'b1;
      @(posedge clk);
      #1;
      if(i==3) check(1'b1);
      else check(1'b0);
    end
    // ---------- 定向 2：输入 1011011，只检测到 1 次（和重叠版的区别）----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<7;i++) begin
      @(negedge clk);
      if(i==1||i==4) din=1'b0;
      else din = 1'b1;
      @(posedge clk);
      #1;
      if(i==3) check(1'b1);
      else check(1'b0);
    end

    // ---------- 定向 3：输入 10111011，检测到 2 次 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<8;i++) begin
      @(negedge clk);
      if(i==1||i==5) din=1'b0;
      else din = 1'b1;
      @(posedge clk);
      #1;
      if(i==3||i==7) check(1'b1);
      else check(1'b0);
    end

    // ---------- 定向 4：部分匹配后失败，输入 101011，检测到 1 次 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<6;i++) begin
      @(negedge clk);
      if(i==1||i==3) din=1'b0;
      else din = 1'b1;
      @(posedge clk);
      #1;
      if(i==5) check(1'b1);
      else check(1'b0);
    end
    // ---------- 定向 5：已输入 101 时复位，复位后再输入 1，不能检测到 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<5;i++) begin 
      @(negedge clk);
      if(i==0||i==2)din = 1'b1;
      else if(i==1) din=1'b0; 
      else if(i==3) begin rst=1'b1;din=1'b0; end
      else if(i==4) begin rst=1'b0;din=1'b1; end
      @(posedge clk);
      #1;
      check(1'b0);
    end
    // ---------- 随机：500 个周期 ----------
    // TODO：din 随机，rst 偶尔为 1；用参考模型做期望值，每拍检查
    //       统计随机阶段 det 为 1 的次数
    repeat(500) begin 
      @(negedge clk);
      din = $urandom();
      rst = ($urandom_range(0,99)<5);
      @(posedge clk);
      #1;
      check(expDet);
      if(det)
        detNum++;
    end

    // ---------- 汇总 ----------
    // TODO：打印检查次数、错误数、随机阶段 det 为 1 的次数；没有错误时打印 PASS（带检查次数）
    if(errCnt||modelError)
      $display("errCnt:%0d,modelError:%0d,detNum:%0d",errCnt,modelError,detNum);
    else 
      $display("PASS");
    $display("checkCnt:%0d",checkCnt);
    $finish;
  end
endmodule
