// bin2gray.v：二进制码 → 格雷码（纯组合逻辑）
// 端口说明：
//   bin  ：输入的二进制码（W 位）
//   gray ：输出的格雷码（W 位）
`timescale 1ns / 1ps
module bin2gray #(
  parameter W = 4
) (
  input  wire [W-1:0] bin,
  output wire [W-1:0] gray
);
  // TODO：实现二进制码到格雷码的转换（任意位宽 W 都要正确）
  //bin >> 1 的最高位补的是 0，而 x ^ 0 = x
  assign gray = bin ^ (bin >> 1);
endmodule
