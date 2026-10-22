// tb_adder_n.sv：adder_n 的自检查 testbench（定向用例 + 随机用例）
// 仅用于仿真，用法：run.bat tb_adder_n [-sv_seed 123]
module tb_adder_n;
  localparam int N = 16;
  // TODO：声明信号、计数器
  logic [N-1:0] a;
  logic [N-1:0] b;
  logic cin;
  logic [N-1:0] sum;
  logic cout;
  int err_cnt;

  //实例化DUT
  adder_n a_dut(.a(a),.b(b),.cin(cin),.sum(sum),.cout(cout));
  // TODO：参考模型 function（返回 N+1 位）
  function automatic logic [N:0] ref_add(
    input logic [N-1:0] a,
    input logic [N-1:0] b,
    input logic cin
  );
    logic [N:0] result = a+b+cin;
    return result; 
  endfunction


  // TODO：check() task
  task automatic check();
    logic [N:0] exp;
    #1;
    exp = ref_add(a,b,cin);
    if(exp!=={cout,sum})begin
      err_cnt++;
      $display("ERROR：a:%h b:%h cin:%h exp:%h prac:%h",a,b,cin,exp,{cout,sum});
    end

  endtask

  initial begin
    // TODO：定向用例（边界值）
    a = 16'h0; b = 16'h0; cin = 1'b0;
    check();
    a = 16'hffff;
    check();
    b = 16'hffff;
    check();
    b = 16'h0;
    cin = 1'b1;
    check();
    
    // TODO：随机用例 repeat (10000)
    repeat(10000) begin
      a = $urandom();
      b = $urandom();
      cin = $urandom_range(1,0);
      check(); 
    end
    

    // TODO：汇总并打印 PASS/FAIL
    if(err_cnt)begin
      $display("ERROR:%0d errors",err_cnt);
    end
    else
      $display("PASS");
    $finish;
  end
endmodule
