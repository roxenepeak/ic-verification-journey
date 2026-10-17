// 04: concurrent assertion (SVA) + bind
// case 1 should pass silently; case 2 should print exactly ONE assertion error
module dut (input logic clk, rst_n, req, slow, output logic ack);
  logic [5:0] sh;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) sh <= '0;
    else        sh <= {sh[4:0], req};
  assign ack = slow ? sh[5] : sh[1];               // slow mode answers too late
endmodule

module req_ack_chk (input logic clk, rst_n, req, ack);
  property p_req_ack;
    @(posedge clk) disable iff (!rst_n) $rose(req) |-> ##[1:3] ack;
  endproperty
  a_req_ack: assert property (p_req_ack)
    else $error("ASSERTION FAILED: no ack within 3 cycles after req (t=%0t)", $time);
endmodule

// attach the checker to every dut instance without touching dut code
bind dut req_ack_chk u_chk (.clk(clk), .rst_n(rst_n), .req(req), .ack(ack));

module tb;
  logic clk = 0, rst_n = 0, req = 0, slow = 0;
  logic ack;
  always #5 clk = ~clk;
  dut u_dut (.*);

  initial begin
    repeat (2) @(negedge clk); rst_n = 1;
    $display("--- case 1: normal ack, expect NO assertion error ---");
    @(negedge clk) req = 1;
    @(negedge clk) req = 0;
    repeat (8) @(negedge clk);
    $display("--- case 2: slow ack, expect ONE assertion error ---");
    slow = 1;
    @(negedge clk) req = 1;
    @(negedge clk) req = 0;
    repeat (10) @(negedge clk);
    $display("--- done ---");
    $finish;
  end
endmodule
