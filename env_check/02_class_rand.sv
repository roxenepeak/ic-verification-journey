// 02: class / inheritance / virtual method / constrained random (dist, solve...before)
module tb;
  class base;
    rand bit [7:0] addr;
    rand bit [3:0] len;
    rand bit       is_write;
    constraint c_addr  { addr inside {[8'h10:8'h1F], 8'hF0}; }
    constraint c_len   { len dist { 1 := 5, [2:4] :/ 3, 15 := 2 }; }
    constraint c_order { solve is_write before len; is_write -> len < 8; }
    virtual function string name(); return "base"; endfunction
    function void show();
      $display("%s: addr=%h len=%0d is_write=%0d", name(), addr, len, is_write);
    endfunction
  endclass

  class child extends base;
    constraint c_child { addr[0] == 1'b0; }          // child adds one more constraint
    virtual function string name(); return "child"; endfunction
  endclass

  initial begin
    base  b;
    child c;
    int   errors;
    errors = 0;
    c = new();
    b = c;                                          // parent handle -> child object
    repeat (20) begin
      if (!b.randomize()) begin $display("randomize() failed"); errors++; end
      b.show();
      if (b.name() != "child")                       errors++;  // virtual method
      if (b.addr[0] != 1'b0)                         errors++;  // child constraint
      if (b.is_write && b.len >= 8)                  errors++;  // implication
      if (!(b.addr inside {[8'h10:8'h1F], 8'hF0}))   errors++;  // inside
    end
    if (!b.randomize() with { len == 3; } || b.len != 3) errors++;  // inline constraint
    if (errors == 0) $display("PASS: class / rand");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
