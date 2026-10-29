// tb_edge_det.sv：边沿检测器的自检查 testbench
// 用法：run.bat tb_edge_det
module tb_edge_det;
  logic clk, rst, din;
  logic rise, fall;
  logic expRise,expFall;
  logic [1:0] hist;//用于存储上一拍和当前拍的din
  int checkCnt,errorCnt,expModelError;

  // TODO：实例化 edge_det
  edge_det dut(.clk(clk),.rst(rst),.din(din),.rise(rise),.fall(fall));

  // TODO：产生时钟，周期 10ns
  initial clk = 0;
  always #5 clk = ~clk;

  // ---------- 参考模型 ----------
  // TODO：产生期望的 rise、fall（思路不能和 DUT 相同）
  always @(posedge clk) begin//时序逻辑只用于记录当前拍和上一拍的din
    if(rst) 
      hist<=2'b00;
    else 
      hist<={hist[0],din};
  end
  always @(*) begin//
    case(hist)
      2'b01:begin expRise=1'b1;expFall=1'b0; end
      2'b10:begin expRise=1'b0;expFall=1'b1; end
      default:begin expRise=1'b0;expFall=1'b0; end
    endcase
  end


  // ---------- 检查 ----------
  // TODO：check task：
  //       1. DUT 和手算期望值比较，不一致打印 DUT ERROR（带时间、期望值、实际值）并计数
  //       2. 参考模型和手算期望值比较，不一致打印 MODEL ERROR 并计数
  //       3. 统计检查次数
  task automatic check(logic handExpRise,logic handExpFALL);
    if(handExpRise!==rise||handExpFALL!==fall) begin
      errorCnt++;
      $display("time:%t,expRise:%b,rise:%b,expFall:%b,fall:%b",$time,handExpRise,rise,handExpFALL,fall);
    end
    if(handExpFALL!==expFall||handExpRise!==expRise) begin
      expModelError++;
      $display("MODEL ERROR");
    end
    checkCnt++;
  endtask


  // ---------- 驱动 ----------
  initial begin
    int i;

    // TODO：0 时刻初始化所有输入，复位，然后释放复位
    rst=1'b1;din=1'b0;
    repeat(2) @(posedge clk);
    #1;
    check(1'b0,1'b0);//检查是否复位成功
    @(negedge clk);
    rst=1'b0;
    // ---------- 定向 1：din 0→1 并保持 1 三拍，只产生一次 rise ----------
    // TODO：每拍都检查，期望值用手算的字面量
    din = 1'b1;
    for (i=0;i<3;i++) begin
      @(posedge clk);
      #1;
      if(i===0) check(1'b1,1'b0);
      else check(1'b0,1'b0);
    end

    // ---------- 定向 2：din 1→0 并保持 0 三拍，只产生一次 fall ----------
    // TODO：每拍都检查，期望值用手算的字面量
    @(negedge clk);
    din = 1'b0;
    for(i=0;i<3;i++)begin
      @(posedge clk);
      #1;
      if(i===0) check(1'b0,1'b1);
      else check(1'b0,1'b0);
    end

    // ---------- 定向 3：din 每拍翻转（0101...，共 6 拍），rise / fall 交替出现 ----------
    // TODO：每拍都检查，期望值用手算的字面量
    for(i=0;i<6;i++) begin 
      @(negedge clk);
      din=~din;
      @(posedge clk);
      #1;
      if(i===0||i===2||i===4)
        check(1'b1,1'b0);
      else if(i===1||i===3||i===5)
        check(1'b0,1'b1);
    end

    // ---------- 定向 4：复位期间 din 变化，不产生 rise / fall ----------
    // TODO：每拍都检查，期望值用手算的字面量
    @(negedge clk);
    rst = 1'b1;din = ~din;
    @(posedge clk);
    #1;
    check(1'b0,1'b0);

    // ---------- 定向 5：复位释放时 din 已经是 1，第一次采样产生一次 rise ----------
    // TODO：每拍都检查，期望值用手算的字面量
    @(negedge clk);
    rst = 1'b0;
    @(posedge clk);
    #1;
    check(1'b1,1'b0);

    // ---------- 随机：300 个周期 ----------
    // TODO：din 随机，rst 偶尔为 1；用参考模型做期望值，每拍检查
    repeat(300) begin
      @(negedge clk);
      din = $urandom();
      rst = ($urandom_range(0,99)<5);
      @(posedge clk);
      #1;
      check(expRise,expFall);
    end

    // ---------- 汇总 ----------
    // TODO：打印检查次数、错误数；没有错误时打印 PASS（带检查次数）
    if(errorCnt || expModelError) 
      $display("errorCnt:%0d,expModelError:%0d",errorCnt,expModelError);
    else
      $display("PASS,check_cnt:%0d",checkCnt);
    $finish;
  end
endmodule
