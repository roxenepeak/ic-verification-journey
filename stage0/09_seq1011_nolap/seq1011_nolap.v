// seq1011_nolap.v：“1011”序列检测器（Moore 型，不允许重叠）
// 端口说明：
//   rst ：同步复位，高有效，回到初始状态
//   din ：串行输入，每个时钟上升沿采样 1 位
//   det ：检测输出。在采到“1011”最后一位的那个上升沿之后，det 为 1，保持一个时钟周期
// 规格：
//   1. Moore 型：det 只由当前状态决定
//   2. 不允许重叠：检测到一次之后，已经用过的位全部作废，从下一位重新开始匹配
//      例如输入 1011011，只检测到 1 次（07 的重叠版会检测到 2 次）；输入 10111011，检测到 2 次
//   3. 复位后从头开始匹配，复位前已匹配的部分作废
module seq1011_nolap (
  input  wire clk,
  input  wire rst,
  input  wire din,
  output wire det
);
  // TODO：按上面的规格实现（三段式状态机）
  //定义状态
  parameter s0=3'd0,s1=3'd1,s2=3'd2,s3=3'd3,s4=3'd4;
  reg [2:0] state,nextState;
  //得到次态
  always @(*) begin
    case(state)
      s0:nextState = din?s1:s0;
      s1:nextState = din?s1:s2;
      s2:nextState = din?s3:s0;
      s3:nextState = din?s4:s2;
      s4:nextState = din?s1:s0;
      default:nextState = s0;
    endcase
  end
  //传递状态
  always @(posedge clk) begin 
    if(rst)
      state<=s0;
    else 
      state<=nextState;
  end 
  //得到输出
  assign det = (state == s4);

endmodule
