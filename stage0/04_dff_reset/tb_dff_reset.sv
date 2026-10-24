// tb_dff_reset.sv：同步/异步复位 DFF 对比的自检查 testbench
// 用法：run.bat tb_dff_reset
// 两个 DUT 共用 clk / rst_n / d，分别输出 q_s（同步）和 q_a（异步）
module tb_dff_reset;
  logic clk;
  logic rst_n;
  logic d;
  logic q_s, q_a;
  int   err_cnt;

  // TODO：实例化 dff_sync_rst（输出接 q_s）和 dff_async_rst（输出接 q_a）
  dff_sync_rst dut1(.clk(clk),.rst_n(rst_n),.d(d),.q(q_s));
  dff_async_rst dut2(.clk(clk),.rst_n(rst_n),.d(d),.q(q_a));

  // TODO：产生时钟，周期 10ns（初值 0，每 5ns 翻转）
  initial clk = 0;
  always #5 clk = ~clk;
  // TODO：check task —— 输入期望值 exp_s、exp_a 和场景名 name（测试场景），
  //       不一致则 err_cnt++ 并打印 时间/场景/期望/实际
  task automatic check(input logic exp_s,input logic exp_a,input string name);
    if(q_s!==exp_s || q_a!== exp_a) begin
      err_cnt++;
      $display("time:%0t,name:%s,exp_s:%d,exp_a:%d,q_s:%d,q_a:%d",$time,name,exp_s,exp_a,q_s,q_a);
    end
    
  endtask



  initial begin
    // 初始化：rst_n=1，d=0，先等两个上升沿让 q 有确定值（d=1 打一拍，q 变 1）
    //先让q变为1，因为已经实例了dut，所以他们的输出会跟着clk变化
    rst_n = 1;
    d = 0;
    @(posedge clk);
    d= 1;
    @(posedge clk);
    #1;

    // ---------- 场景 1：时钟沿之间拉低复位 ----------
    // 在两个上升沿中间（例如 negedge clk 后 #2）把 rst_n 拉 0
    // #1 后检查：q_a 应已为 0，q_s 应保持原值 1
    // 再等到下一个 posedge 后 #1 检查：两者都为 0
    // TODO
    @(negedge clk)
    rst_n = 0;
    #1
    check(1'b1,1'b0,"test1");//因为同步复位下一个上升沿没到来，值还是1'b1，而异步复位只用rst_n和上升沿一个到达即可
    @(posedge clk);
    #1
    check(1'b0,1'b0,"test2");//下一个上升沿到来，值变为1'b0;

    // ---------- 场景 2：复位期间 d 变化 ----------
    // rst_n 保持 0，d 来回翻转并跨过 2 个上升沿
    // 检查：q_s 和 q_a 始终为 0（因为需要测试始终为0，所以每经过一个上升沿就需要测试）
    // TODO
    d=0;
    @(posedge clk);
    d=1;
    #1
    check(1'b0,1'b0,"test3");
    @(posedge clk);
    #1
    check(1'b0,1'b0,"test4");

    // ---------- 场景 3：释放复位后恢复采样 ----------
    // 在 negedge clk 时释放 rst_n=1，d=1
    // 释放后到下一个上升沿之前：两者仍为 0
    // 下一个 posedge 后 #1：两者都为 1
    // TODO
    @(negedge clk);
    rst_n=1;d=1;
    #1
    check(1'b0,1'b0,"test5");
    @(posedge clk);
    #1
    check(1'b1,1'b1,"test6");

    // TODO：汇总，err_cnt==0 打印 PASS，否则打印错误数
    if(err_cnt)
      $display("Fail:%0d errors",err_cnt);
    else
      $display("PASS");
    $finish;
  end
endmodule
