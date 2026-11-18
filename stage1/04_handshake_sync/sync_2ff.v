// sync_2ff.v：单 bit 两级触发器同步器
// 端口说明：
//   clk ：目的时钟域的时钟
//   rst ：目的时钟域的同步复位，高有效
//   d   ：来自源时钟域的单 bit 信号（异步于 clk）
//   q   ：同步到 clk 域之后的信号
// 规格：
//   1. 用两级触发器把 d 同步到 clk 域，q 相对 d 的变化延迟 2～3 个 clk 周期
//   2. 复位时两级触发器都清 0，q=0
//   3. 只能用于单 bit、电平变化足够慢（能被 clk 采到）的信号
`timescale 1ns / 1ps
module sync_2ff (
  input  wire clk,
  input  wire rst,
  input  wire d,
  output wire q
);
  reg sync1,sync2;
  // TODO：按上面的规格实现
  always @(posedge clk) begin 
    if (rst) begin
      sync1<=1'b0;
      sync2<=1'b0;
    end
    else begin
      sync1<=d;
      sync2<=sync1;
    end
  end
  assign q = sync2;//q就是sync2，但是定义sync2更加规范
endmodule
