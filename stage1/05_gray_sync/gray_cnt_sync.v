// gray_cnt_sync.v：用格雷码把 A 域的计数器值同步到 B 域
// 端口说明：
//   clk_a ：A 域时钟
//   rst_a ：A 域同步复位，高有效
//   inc   ：A 域计数使能，为 1 的那一拍计数器加 1（加到最大值后回到 0）
//   cnt_a ：A 域当前的计数值（二进制），寄存器输出
//   clk_b ：B 域时钟（和 clk_a 没有固定的频率、相位关系，可能更快也可能更慢）
//   rst_b ：B 域同步复位，高有效
//   cnt_b ：同步到 B 域后的计数值（二进制）
// 规格：
//   1. A 域：二进制计数器 + 转成格雷码，格雷码必须是寄存器输出（不能把组合逻辑直接送去跨时钟域）
//   2. 格雷码的每一位都用 sync_2ff 同步到 B 域，不能直接使用 A 域的信号
//   3. B 域：把同步后的格雷码转回二进制，得到 cnt_b
//   4. 转换必须例化 bin2gray、gray2bin
//   5. cnt_b 只能是 cnt_a 曾经出现过的值；cnt_a 停止变化后，cnt_b 经过几个 clk_b 周期后等于 cnt_a
//   6. 复位：rst_a 有效后 cnt_a=0；rst_b 有效后 cnt_b=0（各时钟域用自己的复位）
`timescale 1ns / 1ps
module gray_cnt_sync #(
  parameter W = 4
) (
  input  wire         clk_a,
  input  wire         rst_a,
  input  wire         inc,
  output reg [W-1:0] cnt_a,
  input  wire         clk_b,
  input  wire         rst_b,
  output reg [W-1:0] cnt_b
);
  // TODO：按上面的规格实现（输出端口的 wire/reg 类型可以按需要修改）
  wire [W-1:0] temp_gray_a;
  reg  [W-1:0] gray_a;
  wire [W-1:0] gray_b;
  wire [W-1:0] temp_cnt_b;
  //A域
  always @(posedge clk_a) begin
    if(rst_a) cnt_a <= 0;
    else begin 
      if(inc) cnt_a <= cnt_a + 1;
    end
  end
  //将二进制转换为格雷码，并用寄存器打一拍
  bin2gray #(.W(W)) mod1(.bin(cnt_a),.gray(temp_gray_a));
  always @(posedge clk_a) begin
    if(rst_a) gray_a<=0;
    else gray_a<=temp_gray_a;//不能直接用组合逻辑的temp_gray_a去同步，会采集到组合逻辑的毛刺
  end
  //将格雷码同步到b域(注意要每一位分开同步，用generate模块)
  genvar i;
  generate 
    for(i=0;i<W;i++) begin:sync_array
      sync_2ff sync_mod(.clk(clk_b),.rst(rst_b),.d(gray_a[i]),.q(gray_b[i]));
    end 
  endgenerate
  //B域
  //将格雷码转换为二进制
  gray2bin #(.W(W)) mod2(.gray(gray_b),.bin(temp_cnt_b));
  always @(posedge clk_b) begin
    if(rst_b) cnt_b<=0;
    else cnt_b <= temp_cnt_b;
  end
endmodule
