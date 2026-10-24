// dff_sync_rst.v：同步复位 D 触发器（低有效复位 rst_n）
// 要求：只在 clk 上升沿采样 rst_n；rst_n=0 时 q 清 0，否则 q <= d
module dff_sync_rst (
  input  wire clk,
  input  wire rst_n,
  input  wire d,
  output reg  q
);
  // TODO：用 always @(posedge clk) 实现，注意用非阻塞赋值 <=
  always @(posedge clk) begin
    if(!rst_n)
      q<=1'b0;
    else
      q<=d;
  end

endmodule
