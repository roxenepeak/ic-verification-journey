`include "uvm_macros.svh"
import uvm_pkg::*;

class hello_test extends uvm_test;
  `uvm_component_utils(hello_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("HELLO", "UVM hello world!", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

module tb;
  initial run_test();
endmodule