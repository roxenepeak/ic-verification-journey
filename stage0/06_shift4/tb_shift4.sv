// tb_shift4.sv：4 位双向移位寄存器的自检查 testbench（定向 + 随机 + 参考模型 + 简单覆盖统计）
// 用法：run.bat tb_shift4
// 和 05 相比的三处改进（来自 10-26 检查 progress 的意见）：
//   1. 参考模型换一种写法独立写，不照抄 DUT
//   2. 定向测试的期望值用手算的字面量，并顺便检查参考模型是否也等于它（交叉验证）
//   3. 随机测试统计每种 mode 出现的次数（最简单的“覆盖率”）
module tb_shift4;
  logic       clk, rst;
  logic [1:0] mode;
  logic       si_r, si_l;
  logic [3:0] d;
  logic [3:0] q;
  logic [3:0] exp_q;          // 参考模型的状态
  int         err_cnt, chk_cnt;
  int         mode_cnt[4];    // 随机阶段每种 mode 出现的次数（rst=1 的那拍不算）



  // TODO：实例化 shift4（用命名端口连接）
  shift4 dut(.clk(clk),.rst(rst),.mode(mode),.si_r(si_r),.si_l(si_l),.d(d),.q(q));

  // TODO：产生时钟，周期 10ns
  initial clk = 0;
  always #5 clk = ~clk;

  // ---------- 参考模型 ----------
  // TODO：在 posedge clk 上用 <= 更新 exp_q，行为按 shift4.v 开头的规格
  //       要求：写法要和 DUT 不一样，二选一：
  //         (a) DUT 用 case + 拼接，模型就用 if-else 链 + 逐位赋值（比如右移写成 exp_q[i] <= exp_q[i+1] 的形式）
  //         (b) 写一个 function 算下一状态：function automatic logic [3:0] next_q(...); 然后 exp_q <= next_q(...);
  //       目的：两份代码写法不同，同一个理解错误才不容易在两边同时出现
  
  always @(posedge clk) begin
    if(rst)
      exp_q<=4'b0;
    else 
      exp_q<=get_next_exp_q();
  end  
  
  function automatic logic[3:0] get_next_exp_q();

  logic [3:0] next_exp_q;//参考模型的中间变量
    case(mode)
      2'b00:next_exp_q = exp_q;
      2'b01:next_exp_q = {si_r,exp_q[3:1]};
      2'b10:next_exp_q = {exp_q[2:0],si_l};
      2'b11:next_exp_q = d;
    endcase
  return next_exp_q;  

  endfunction

  // ---------- 检查 ----------
  // TODO：task automatic check(input logic [3:0] exp, input string tag);
  //      比较 q 和 exp：不一致则 err_cnt++，打印 时间 / tag / 期望 / 实际（4 位用 %b，方便看移位）
  task automatic check(input logic [3:0] exp,input string tag);
    if(q!==exp) begin 
      err_cnt++;
      $display("time:%0d,tag:%s,exp:%b,q:%b",$time,tag,exp,q);
    end
    chk_cnt++;
  endtask



  // ---------- 驱动 ----------
  // 约定：输入只在 negedge clk 改；检查在 posedge clk 之后调用 check（task 里先 #1）
  initial begin
    int i;
    // TODO：0 时刻就给所有输入赋初值（不要先等 negedge）：rst=1，mode=00，si_r=0，si_l=0，d=0
    //       用 repeat(2) @(posedge clk) 等两个上升沿，然后 check(4'b0000, "reset")
    //       再在 negedge 释放复位
    rst=1'b1;mode=2'b0;si_r=1'b0;si_l=1'b0;d=4'b0;
    repeat(2) @(posedge clk) ;
    #1;
    check(4'b0,"reset");
    @(negedge clk);
    rst=1'b0;

    // ---------- 定向 1：并行加载 d=4'b1011 ----------
    // TODO：期望值写成字面量(字面量就是固定值)
    @(negedge clk);
    d=4'b1011;mode=2'b11;
    @(posedge clk);//如果check模块包含时序逻辑，修改值后需要等待有效沿后才能check
    #1;
    check(4'b1011,"check1");

    // ---------- 定向 2：右移 4 拍，si_r 依次给 1、0、0、1 ----------
    // TODO：从 4'b1011 开始，先在纸上算出 4 拍各自的结果，再写成 4 个字面量期望值
    //       同时把 si_l 故意给成和 si_r 相反的值，确认右移时 si_l 不起作用
    for(i=0;i<4;i++) begin 
      @(negedge clk);
      mode=2'b01;
      case(i)
        0:begin si_r=1'b1;si_l=1'b0;@(posedge clk);#1;check(4'b1101,"check2");end 
        1:begin si_r=1'b0;si_l=1'b1;@(posedge clk);#1;check(4'b0110,"check2");end 
        2:begin si_r=1'b0;si_l=1'b1;@(posedge clk);#1;check(4'b0011,"check2");end
        3:begin si_r=1'b1;si_l=1'b0;@(posedge clk);#1;check(4'b1001,"check2");end
      endcase
    end 

    // ---------- 定向 3：左移 4 拍，si_l 依次给 0、1、1、0 ----------
    // TODO：接着定向 2 的结果继续移，期望值手算；si_r 同样给相反值
    for(i=0;i<4;i++) begin 
      @(negedge clk);
      mode=2'b10;
      case(i)
        0:begin si_r=1'b1;si_l=1'b0;@(posedge clk);#1;check(4'b0010,"check3");end
        1:begin si_r=1'b0;si_l=1'b1;@(posedge clk);#1;check(4'b0101,"check3");end
        2:begin si_r=1'b0;si_l=1'b1;@(posedge clk);#1;check(4'b1011,"check3");end
        3:begin si_r=1'b1;si_l=1'b0;@(posedge clk);#1;check(4'b0110,"check3");end
      endcase
    end 


    // ---------- 定向 4：保持 3 拍（mode=00），其间 si_r / si_l / d 每拍都变，q 不能变 ----------
    // TODO
    repeat(3) begin
      @(negedge clk);
      mode=2'b00;si_r = $urandom();si_l=$urandom();d=$urandom();
      @(posedge clk);
      #1;
      check(exp_q,"check4");//不用字面量(最好用字面量，这里不用只是提醒我这种写法)
    end

    // ---------- 定向 5：rst 优先于加载（rst=1 且 mode=11、d=4'b1111，结果应为 0）----------
    // TODO
    @(negedge clk);
    rst=1'b1;mode=2'b11;d=4'b1111;
    @(posedge clk);
    #1;
    check(4'b0,"check5");

    // ---------- 随机：300 个周期 ----------
    // TODO：每个 negedge 随机给 mode / si_r / si_l / d，rst 约 5% 概率为 1
    //       posedge 后 check(exp_q, "rand")
    //       rst=0 时 mode_cnt[mode]++
    repeat(300) begin
      @(negedge clk);
      rst = ($urandom_range(0,99) < 5);
      mode=$urandom();si_r=$urandom();si_l=$urandom();d=$urandom();
      if(~rst)
        mode_cnt[mode]++;
      @(posedge clk);
      #1;
      check(exp_q,"check6");
    end

    // ---------- 汇总 ----------
    // TODO：打印 mode_cnt 的四个值
    //       打印检查次数和错误数；err_cnt==0 时打印 PASS（PASS 这一行也要带上检查次数）
    if(err_cnt)
      $display("ERROR:%0d,check_cnt:%0d",err_cnt,chk_cnt);
    else
      $display("PASS,check_cnt:%0d",chk_cnt);
    $display("mode_cnt[0]=%0d,mode_cnt[1]=%0d,mode_cnt[2]=%0d,mode_cnt[3]=%0d",mode_cnt[0],mode_cnt[1],mode_cnt[2],mode_cnt[3]);

    $finish;
  end
endmodule
