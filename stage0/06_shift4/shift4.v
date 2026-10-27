// shift4.v：带并行加载的 4 位双向移位寄存器
// 端口说明：
//   rst  ：同步复位，高有效，q 清 0
//   mode ：工作模式
//          2'b00：保持     q 不变
//          2'b01：右移     q 整体往低位移 1 位：si_r 进入 q[3]，q[0] 被移出丢掉
//          2'b10：左移     q 整体往高位移 1 位：si_l 进入 q[0]，q[3] 被移出丢掉
//          2'b11：并行加载 q <= d
//   si_r ：右移时的串行输入（只在 mode=01 时起作用）
//   si_l ：左移时的串行输入（只在 mode=10 时起作用）
//   d    ：并行加载的数据
// 优先级：rst > mode

module shift4 (
  input  wire       clk,
  input  wire       rst,
  input  wire [1:0] mode,
  input  wire       si_r,
  input  wire       si_l,
  input  wire [3:0] d,
  output reg  [3:0] q
);
  // TODO：用 always @(posedge clk) 和 <= 写；先判断 rst，其余按 mode 分四种情况
  //       移位用拼接 {} 写
  always @(posedge clk) begin
    if(rst) 
      q<=4'b0;
    else begin
      case(mode)
        2'b00:q<=q;
        2'b01:q<={si_r,q[3:1]};
        2'b10:q<={q[2:0],si_l};
        2'b11:q<=d;
      endcase
    end

  end

endmodule
