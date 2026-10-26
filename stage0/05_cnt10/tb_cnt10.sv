// tb_cnt10.sv：十进制计数器的自检查 testbench（定向 + 随机 + 参考模型）
// 用法：run.bat tb_cnt10
// 随机测试时期望值没法提前手写，由 tb 里的模型每拍算出来
module tb_cnt10;
  logic       clk, rst, load, ena;
  logic [3:0] d;
  logic [3:0] q;
  logic       co;
  logic [3:0] exp_q;      // 参考模型的状态
  int         err_cnt, chk_cnt;

  // TODO：实例化 cnt10
  cnt10 dut(.clk(clk),.rst(rst),.load(load),.ena(ena),.d(d),.q(q),.co(co));

  // TODO：产生时钟，周期 10ns
  initial clk = 0;
  always #5 clk = ~clk;//5ns翻转一次即可

  // ---------- 参考模型 ----------
  // TODO：在 posedge clk 上按“rst > load > ena”更新 exp_q（行为和 DUT 一样，但要自己独立写，不要复制 DUT）
  wire exp_co = ena && (exp_q==4'h9);//注意这里必须用wire变量，用logic表示赋的是初值，wire表示连续赋值
  always @(posedge clk) begin //不能写在function块中
    if(rst)
      exp_q<=0;
    else if(load) 
      exp_q<=d;
    else if(ena) begin
      exp_q<=exp_q+4'h1;
      if(exp_co) begin 
        exp_q<=4'h0;
      end
    end
  end

  // ---------- 检查 ----------
  // TODO：check task：比较 q 和 exp_q、co 和期望进位
  //       不一致则 err_cnt++ 并打印 时间/场景/期望/实际（1 位用 %b，4 位用 %0d）；每调用一次 chk_cnt++
  task automatic check();
    #1;//每次check前都要完成这步
    if(q!==exp_q || co!==exp_co) begin 
      err_cnt++;
      $display("time:%0d,exp_q:%0d,exp_co:%b,q:%0d,co:%b",$time,exp_q,exp_co,q,co);
    end
    chk_cnt++;
  endtask


  // ---------- 驱动 ----------
  // 约定：所有输入都在 negedge clk 改，检查在 negedge clk 改输入之前做（或 posedge 后 #1）
  initial begin
    // TODO：初始化：rst=1，其余输入为 0，等 2 个时钟沿后释放复位
    @(negedge clk);
    rst = 1'b1; load = 1'b0;ena = 1'b0;d = 4'b0;
   // #20;//等待两个上升时钟沿即两个时钟周期（建议不要这样写，以后修改时钟周期后会出错）
    repeat(2) @(posedge clk);
    @(negedge clk)
    rst = 1'b0;


    // ---------- 定向 1：连续计数 0→9→0，检查 co 只在 q==9 时为 1 ----------
    // TODO
    @(negedge clk);
    ena = 1'b1; load = 1'b0;rst = 1'b0;
    repeat(12) begin//连续计数0->9需要9拍，再回到0要10拍，可以多预留两拍
      @(posedge clk);
        check();//这里用check即可，因为会和标准模型做比较，eco满足上面的条件
    end
   
    
    // ---------- 定向 2：ena=0 时保持 ----------
    // TODO
    @(negedge clk);
    ena = 1'b0;load = 1'b0;rst = 1'b0;
    @(posedge clk);//每次修改值后要测试修改后的结果需要等待下一次上升沿到来
    check();

    // ---------- 定向 3：load 优先于 ena（load=1, ena=1 同时给，结果应为 d）----------
    // TODO
    @(negedge clk);
    ena = 1'b1;load = 1'b1;rst = 1'b0;d=4'h2;//这里的d需要赋值，不然load前后没有差别
    @(posedge clk);
    check();
    

    // ---------- 定向 4：rst 优先于 load ----------
    // TODO
     @(negedge clk);
    ena = 1'b0;load = 1'b1;rst = 1'b1;
    @(posedge clk);
    check();


    // ---------- 随机：300 个周期 ----------
    // TODO：每个 negedge 随机给 load/ena/d（d 用 $urandom_range(0,9)），rst 偶尔为 1（比如 5% 概率）
    //       每拍检查一次
    for(int i=0;i<300;i++) begin
      @(negedge clk);
      load = $urandom();
      ena = $urandom();
      d = $urandom_range(0,9);
      rst = ($urandom_range(0,99) < 5);
      @(posedge clk);
      check();
    end

    // TODO：汇总：打印检查次数、错误数，err_cnt==0 打印 PASS
    if(err_cnt)
      $display("ERROR,err_cnt:%0d,chk_cnt:%0d",err_cnt,chk_cnt);
    else
      $display("PASS");

    $finish;
  end
endmodule
