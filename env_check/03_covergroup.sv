// 03: covergroup + cross, then generate a report with xcrg
module tb;
  bit [1:0] op;
  bit [2:0] size;

  covergroup cg;
    cp_op:   coverpoint op   { bins rd = {0}; bins wr = {1}; bins other = {[2:3]}; }
    cp_size: coverpoint size { bins lo = {[0:3]}; bins hi = {[4:7]}; }
    x_op_size: cross cp_op, cp_size;                 // 3 x 2 = 6 cross bins
  endgroup

  cg cov = new();

  initial begin
    real pct;
    repeat (200) begin
      op   = 2'($urandom);
      size = 3'($urandom);
      cov.sample();
    end
    pct = cov.get_coverage();
    $display("functional coverage = %0.2f%%", pct);
    if (pct == 100.0) $display("PASS: covergroup");
    else              $display("FAIL: coverage not 100%%");
    $finish;
  end
endmodule
