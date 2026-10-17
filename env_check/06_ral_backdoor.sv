// 06: UVM register model backdoor (hdl_path, needs simulator DPI/VPI support)
`include "uvm_macros.svh"
import uvm_pkg::*;

module dut;
  logic [7:0] ctrl = 8'h5A;                        // the "register" inside the design
endmodule

class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)
  rand uvm_reg_field val;
  function new(string name = "ctrl_reg");
    super.new(name, 8, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    val = uvm_reg_field::type_id::create("val");
    val.configure(this, 8, 0, "RW", 0, 8'h00, 1, 1, 0);
  endfunction
endclass

class my_block extends uvm_reg_block;
  `uvm_object_utils(my_block)
  rand ctrl_reg ctrl;
  function new(string name = "my_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    default_map = create_map("map", 0, 1, UVM_LITTLE_ENDIAN);
    ctrl = ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this, null, "ctrl");            // hdl path of this register: "ctrl"
    ctrl.build();
    default_map.add_reg(ctrl, 0, "RW");
    add_hdl_path("tb.u_dut");                      // full path = tb.u_dut.ctrl
    lock_model();
  endfunction
endclass

class ral_test extends uvm_test;
  `uvm_component_utils(ral_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    my_block       blk;
    uvm_status_e   st;
    uvm_reg_data_t v;
    phase.raise_objection(this);
    blk = my_block::type_id::create("blk");
    blk.build();

    blk.ctrl.peek(st, v);                          // backdoor read
    if (st == UVM_IS_OK && v == 8'h5A) begin
      `uvm_info("RAL", "PASS: backdoor peek read 5A", UVM_LOW)
    end else begin
      `uvm_error("RAL", $sformatf("FAIL: peek status=%s value=%h", st.name(), v))
    end

    blk.ctrl.poke(st, 8'hA5);                      // backdoor write
    blk.ctrl.peek(st, v);
    if (st == UVM_IS_OK && v == 8'hA5) begin
      `uvm_info("RAL", "PASS: backdoor poke wrote A5", UVM_LOW)
    end else begin
      `uvm_error("RAL", $sformatf("FAIL: after poke status=%s value=%h", st.name(), v))
    end
    phase.drop_objection(this);
  endtask
endclass

module tb;
  dut u_dut ();
  initial run_test("ral_test");
endmodule
