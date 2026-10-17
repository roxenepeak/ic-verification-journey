// 05: code coverage (statement / branch / condition / toggle)
// some branches are NOT exercised on purpose, so the report must show < 100%
module alu (input logic clk, input logic [1:0] op, input logic [7:0] a, b,
            output logic [7:0] y);
  always_ff @(posedge clk)
    case (op)
      2'd0: y <= a + b;
      2'd1: y <= a - b;
      2'd2: if (a > b && b != 0) y <= a; else y <= b;
      default: y <= 8'hFF;                         // never hit by the test
    endcase
endmodule

module tb;
  logic clk = 0;
  logic [1:0] op;
  logic [7:0] a, b, y;
  always #5 clk = ~clk;
  alu u_alu (.*);
  initial begin
    repeat (20) begin
      @(negedge clk);
      op = 2'($urandom_range(0, 2));                  // op 3 never generated
      a  = 8'($urandom);
      b  = 8'($urandom);
    end
    $display("done, now run xcrg to see the code coverage report");
    $finish;
  end
endmodule
