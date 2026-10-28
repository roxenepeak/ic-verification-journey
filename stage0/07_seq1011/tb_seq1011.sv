// tb_seq1011.sv：“1011”序列检测器的自检查 testbench
// 用法：run.bat tb_seq1011
module tb_seq1011;
  logic clk, rst, din;
  logic det;

  parameter a=3'b000,b=3'b001,c=3'b010,d=3'b011,e=3'b100;//定义状态
  logic [2:0] state,nextState;
  wire expDet =  (state==e);//参考模型的结果（必须使用连续赋值）

  int errorCnt = 0,checkCnt = 0;

  // TODO：实例化 seq1011
  seq1011 dut(.clk(clk),.rst(rst),.din(din),.det(det));

  // TODO：产生时钟，周期 10ns
  initial clk = 0;
  always #5 clk = ~clk;

  // ---------- 参考模型 ----------
  // TODO：产生期望的 det
  always @(posedge clk) begin //传递状态
    if(rst)
      state<=a;
    else
      state<=GetNextState();
  end
    
  function automatic logic[2:0] GetNextState();//得到下一个状态
      //得到下一个状态
      if(state===a)//0
        nextState=din?b:a;
      else if(state===b)//1
        nextState=din?b:c;
      else if(state===c)//10
        nextState=din?d:a;
      else if(state===d)//101
        nextState=din?e:c;
      else if(state===e)//1011
        nextState=din?b:c;
      return nextState;
  endfunction


  // ---------- 检查 ----------
  // TODO：check task
  task automatic check(input logic exp);//传入手算字面量
    //没有输入可以在check中延时，这里有输入不能延时
    if(expDet!==det || exp!==det) begin 
      errorCnt++;
      $display("time:%t,expDet:%b,det:%b",$time,expDet,det);
    end
    checkCnt++;
  endtask


  // ---------- 驱动 ----------
  initial begin
    int i;
    // TODO：0 时刻初始化所有输入，复位，然后释放复位
    rst = 1'b1; din = 1'b0;          // 0 时刻就复位
    repeat(2) @(posedge clk); #1;
    check(1'b0);                     // 复位后 det 应为 0
    @(negedge clk); rst = 1'b0;      // 在 negedge 释放

    // ---------- 定向 1：输入 1011，det 只在应该为 1 的那一拍为 1 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<4;i++) begin
      @(negedge clk);
      if(i===1)
        din = 1'b0;
      else 
        din = 1'b1;
      @(posedge clk);
      if(i===3) begin
        #1;
        check(1'b1);
      end
      else begin
        #1;
        check(1'b0);
      end
    end

    // ---------- 定向 2：重叠，输入 1011011，应检测到 2 次 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<7;i++)begin
      @(negedge clk);
      if(i===1 || i===4)
        din = 1'b0;
      else 
        din = 1'b1;
      @(posedge clk);
      if(i===3||i===6) begin 
        #1;
        check(1'b1);
      end
      else begin 
        #1;
        check(1'b0);
      end
    end

    // ---------- 定向 3：部分匹配后失败，输入 101011，应检测到 1 次 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<6;i++) begin
      @(negedge clk);
      if(i===1||i===3)
        din = 1'b0;
      else 
        din = 1'b1;
      @(posedge clk);
      if(i===5) begin
        #1;
        check(1'b1);
      end
      else begin 
        #1;
        check(1'b0);
      end
    end

    // ---------- 定向 4：只差一位的序列 1010、1001，det 不能为 1 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<4;i++) begin
      @(negedge clk);
      if(i===1||i===3)
        din = 1'b0;
      else 
        din = 1'b1;
      @(posedge clk);
      #1;
      check(1'b0);
    end
    for(i=0;i<4;i++) begin
      @(negedge clk);
      if(i===1||i===2)
        din = 1'b0;
      else 
        din = 1'b1;
      @(posedge clk);
      #1;
      check(1'b0);
    end

    // ---------- 定向 5：已输入 101 时复位，复位后再输入 1，det 不能为 1 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<5;i++) begin
      @(negedge clk);
      if(i===3)  
        rst=1'b1;
      else if(i===4) begin 
        rst=1'b0;
        din=1'b1;
      end
      else if(i===1) 
        din = 1'b0;
      else 
        din = 1'b1;
      @(posedge clk);
      #1;
      check(1'b0);
    end

    // ---------- 随机：500 个周期 ----------
    // TODO：din 随机，rst 偶尔为 1；用参考模型做期望值，每拍检查
    repeat(500) begin
      @(negedge clk);
      din = $urandom;
      rst = ($urandom_range(0,99)<5);
      @(posedge clk);
      #1;
      check(expDet);
    end

    // ---------- 汇总 ----------
    // TODO：打印检查次数、错误数没有错误时打印 PASS（带检查次数）
    if(errorCnt) 
      $display("checkCnt:%0d,errorCnt:%0d",checkCnt,errorCnt);
    else 
      $display("PASS checkCnt:%0d",checkCnt);

    $finish;
  end
endmodule
