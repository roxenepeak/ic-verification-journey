// pulse_sync.v：单 bit 脉冲跨时钟域同步（A 域 → B 域）
// 端口说明：
//   clk_a   ：源时钟域时钟
//   rst_a   ：源时钟域同步复位，高有效
//   pulse_a ：源时钟域的输入脉冲，每次只持续 1 个 clk_a 周期
//   clk_b   ：目的时钟域时钟（和 clk_a 没有固定的频率、相位关系，可能更快也可能更慢）
//   rst_b   ：目的时钟域同步复位，高有效
//   pulse_b ：目的时钟域的输出脉冲，每次只持续 1 个 clk_b 周期
// 规格：
//   1. pulse_a 每出现一次，pulse_b 恰好出现一次，宽度 1 个 clk_b 周期，不多不少（双边沿检测）
//   2. 无论 clk_a 比 clk_b 快还是慢都要正确
//   3. 使用条件：相邻两个 pulse_a 之间至少间隔 MIN_GAP 个 clk_b 周期（MIN_GAP 见 tb），
//      间隔太近时不保证正确——这是这种结构本身的限制
//   4. 要用 sync_2ff（电平同步器） 做跨时钟域的那一步，不能直接把 A 域的信号拿到 B 域用
//   5. 复位：rst_a、rst_b 都有效后，pulse_b=0（各个时钟域用自己的复位信号）
`timescale 1ns / 1ps
module pulse_sync (
  input  wire clk_a,
  input  wire rst_a,
  input  wire pulse_a,
  input  wire clk_b,
  input  wire rst_b,
  output wire pulse_b
);
  wire sync2;
  reg sync3,toggle;
  //实例化电平同步器
  sync_2ff s1(.clk(clk_b),.rst(rst_b),.d(toggle),.q(sync2));//在电平同步器中打了两拍，目的时钟域只用打一拍
  //源时钟域
  always @(posedge clk_a) begin 
    if(rst_a)
      toggle<=1'b0;
    else if(pulse_a)
      toggle<=~toggle;
  end

  //目的时钟域
  always @(posedge clk_b) begin
    if(rst_b)
      sync3<=1'b0;
    else 
      sync3<=sync2;
  end

  assign pulse_b = sync2 ^ sync3;
endmodule
