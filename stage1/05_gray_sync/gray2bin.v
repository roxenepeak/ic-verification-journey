// gray2bin.v：格雷码 → 二进制码（纯组合逻辑）
// 端口说明：
//   gray ：输入的格雷码（W 位）
//   bin  ：输出的二进制码（W 位）
`timescale 1ns / 1ps
module gray2bin #(
  parameter W = 4
) (
  input  wire [W-1:0] gray,
  output reg [W-1:0] bin
);
  // TODO：实现格雷码到二进制码的转换（任意位宽 W 都要正确）
  integer i;
  always @(*) begin 
    bin[W-1] = gray[W-1];
    for(i=W-2;i>=0;i--) begin
      bin[i] = gray[i] ^ bin[i+1];
    end
  end
endmodule
