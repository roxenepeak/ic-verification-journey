// dff_async_rst.v：异步复位 D 触发器（低有效复位 rst_n）
// 要求：rst_n 一拉低 q 立刻清 0（不等时钟）；否则 clk 上升沿 q <= d
module dff_async_rst (
  input  wire clk,
  input  wire rst_n,
  input  wire d,
  output reg  q
);
  // TODO：敏感列表里要有什么？想清楚 negedge rst_n 的作用
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
      q<=1'b0;
    else
      q<=d;

  end
endmodule
