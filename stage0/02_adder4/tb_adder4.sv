// tb_adder4.sv：adder4 的自检查 testbench
// 仅用于仿真（不可综合），可以在 xsim 上运行
module tb_adder4;
  logic [3:0] a, b;
  logic       cin;
  logic [3:0] sum;
  logic       cout;
  int err_cnt;                            // 出错次数

  // 被测设计（DUT）：就是你在 adder4.v 里写的模块
  adder4 u_dut (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

  // 参考模型：给出 {cout, sum} 的"正确答案"
  function automatic logic [4:0] ref_add(input logic [3:0] x, y,
                                         input logic       c);
    // TODO 1：返回 x + y + c（注意结果要 5 位）
    logic f_cout;
    logic[3:0] f_sum;
    {f_cout,f_sum} = x+y+c;
    return {f_cout,f_sum};
  endfunction

  // 比较 DUT 的输出和参考模型的结果
  task automatic check();
    logic [4:0] exp;
    #1;                                   // 等组合逻辑稳定
    // TODO 2：算出 exp，和 {cout, sum} 比较；
    //不相等就打印 a、b、cin、期望值、实际值，并让 err_cnt 加 1
    exp = ref_add(a,b,cin);
    if(exp!={cout,sum}) begin
      err_cnt = err_cnt+1;
      $display("ERROR:a:%h b:%h cin:%h exp:%h prac:%h",a,b,cin,exp,{cout,sum});
    end
    
  endtask

  initial begin
    
    // TODO 3：用 int 做循环变量，穷举 a(16) × b(16) × cin(2) 共 512 种，每组调用 check()
    //         （不要用 4 位的 a 直接做循环变量，否则会死循环）
    integer i1,i2,i3;
    integer chk_ent = 0;
    err_cnt = 0;
    a=4'b0;
    b=4'b0;
    cin = 1'b0;
    for(i1=0;i1<16;i1=i1+1) begin
      b = 4'b0;
      for(i2=0;i2<16;i2=i2+1) begin
        cin = 1'b0;
        for(i3=0;i3<2;i3=i3+1)begin
          check();
          cin = cin+4'b1;
          chk_ent++; 
        end
        b = b+4'b1;
      end
      a = a+4'b1;
    end

    $display("检查次数：%d",chk_ent);
    // TODO 4：根据 err_cnt 打印 PASS 或 FAIL
    if(err_cnt) begin
      $display("FAIL：%d errors",err_cnt);
    end
    else
      $display("PASS");
    $finish;
  end
endmodule
