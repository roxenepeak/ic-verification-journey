module counter(input clk, input rst_n, input en, output reg [3:0] cnt);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) cnt <= 0;
    else if (en) cnt <= cnt + 1;
endmodule

module tb_counter;
  reg clk = 0, rst_n = 0, en = 0;
  wire [3:0] cnt;
  counter u_dut(.clk(clk), .rst_n(rst_n), .en(en), .cnt(cnt));
  always #5 clk = ~clk;
  initial begin
    #12 rst_n = 1; en = 1;
    repeat (10) @(posedge clk);
    #1;
    if (cnt == 10) $display("PASS: cnt = %0d", cnt);
    else           $display("FAIL: cnt = %0d", cnt);
    $finish;
  end
endmodule