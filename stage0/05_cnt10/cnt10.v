// cnt10.v：带同步复位、加载、使能的十进制计数器（0~9 循环）
// 端口说明：
//   rst  ：同步复位，高有效，q 清 0
//   load ：同步加载，q <= d（d 只会给 0~9）
//   ena  ：计数使能，q 加 1，9 之后回到 0
//   co   ：进位输出（组合逻辑），当 ena=1 且 q==9 时为 1
// 优先级：rst > load > ena
module cnt10 (
  input  wire       clk,
  input  wire       rst,
  input  wire       load,
  input  wire       ena,
  input  wire [3:0] d,
  output reg  [3:0] q,
  output wire       co
);
  // TODO：时序部分，用 always @(posedge clk) 和 <=，按优先级写
  always @(posedge clk) begin 
    if(rst)
      q<=0;
    else if(load) 
      q<=d;
    else if(ena) begin
      q<=q+4'h1;
      if(co) begin 
        q<=4'h0;
      end
    end
  end
  // TODO：co 用 assign 写
  assign co = ena && (q==4'h9);
endmodule
