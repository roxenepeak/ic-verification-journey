// seq1011.v：“1011”序列检测器（Moore 型，允许重叠）
// 端口说明：
//   rst ：同步复位，高有效，回到初始状态
//   din ：串行输入，每个时钟上升沿采样 1 位
//   det ：检测输出。在采到“1011”最后一位的那个上升沿之后，det 为 1，保持一个时钟周期
// 规格：
//   1. Moore 型：det 只由当前状态决定
//   2. 允许重叠：例如输入 1011011，应检测到 2 次
//   3. 复位后从头开始匹配，复位前已匹配的部分作废
module seq1011 (
  input  wire clk,
  input  wire rst,
  input  wire din,
  output reg det
);
  // TODO：按上面的规格实现（三段式状态机）
  //定义状态(一共有五个状态，0，1,10,101,1011，初始状态为0)
  parameter a=3'b000,b=3'b001,c=3'b010,d=3'b011,e=3'b100;
  reg [2:0] state,nextState;
  //得到下一个状态
  always @(*) begin 
    case(state) 
      3'b000:nextState=din?b:a;
      3'b001:nextState=din?b:c;
      3'b010:nextState=din?d:a;
      3'b011:nextState=din?e:c;
      3'b100:nextState=din?b:c;
      default:nextState=a;//如果出现其他状态则重置状态为a
    endcase
  end
  //给下一个状态赋值
  always@(posedge clk) begin
    if(rst)
      state<=a;
    else
      state<=nextState;
  end
  //得到输出
  always @(*) begin 
    if(state==e) 
      det = 1'b1;
    else
      det = 1'b0;
  end
  
endmodule
