// tb_mux4.sv：mux4 的自检查 testbench
// 仅用于仿真（不可综合），可以在 xsim 上运行
module tb_mux4;
  logic [7:0] in0, in1, in2, in3;
  logic [1:0] sel;
  logic [7:0] q;
  int err_cnt;                            // 出错次数

  // 被测设计（DUT）：就是你在 mux4.v 里写的模块
  mux4 u_dut (.in0(in0), .in1(in1), .in2(in2), .in3(in3), .sel(sel), .q(q));

  // 参考模型：给出 q 的"正确答案"
  function automatic logic [7:0] ref_mux(input logic [1:0] s,
                                         input logic [7:0] a, b, c, d);
    // TODO 1：根据 s 返回 a / b / c / d 中的一个
    case(s)
    2'b00:return a;
    2'b01:return b;
    2'b10:return c;
    2'b11:return d;
    default:return 8'h00;
    endcase   
    return 8'h00;
  endfunction

  // 比较 DUT 的输出和参考模型的结果
  task automatic check();
    logic [7:0] exp;
    #1;                                   // 等组合逻辑稳定
    exp = ref_mux(sel, in0, in1, in2, in3);
    // TODO 2：如果 q != exp，err_cnt 加 1，并用 $display 打印 sel、各个输入、q 和 exp
    if(q!==exp) begin //这里需要使用!==，和!=有区别
      err_cnt = err_cnt+1;
      $display("ERROR:sel=%b,in0=%b,in1=%b,in2=%b,in3=%b,q=%b,exp=%b",sel,in0,in1,in2,in3,q,exp); 
    end

  endtask

  initial begin
    err_cnt = 0;

    // A 部分：定向测试，sel 的每个取值各测一次
    in0 = 8'h11; in1 = 8'h22; in2 = 8'h33; in3 = 8'h44;
    for (int s = 0; s < 4; s++) begin
      sel = 2'(s);
      check();
    end

    // TODO 3：B 部分，随机测试：重复 1000 次，
    //         用 $urandom 给 in0~in3 和 sel 赋随机值，然后调用 check()
    for(int s=0;s<1000;s++)begin 
      sel = $urandom;
      in0 = $urandom;
      in1 = $urandom;
      in2 = $urandom;
      in3 = $urandom;
      check();
    end

    // TODO 4：err_cnt 为 0 就打印 "PASS"，否则打印 "FAIL: <err_cnt> errors"
    if(err_cnt) 
      $display("FAIL:%d errors",err_cnt);
    else
      $display("PASS");
    $finish;
    
  end
endmodule
