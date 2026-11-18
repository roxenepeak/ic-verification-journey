// handshake_sync.v：多 bit 数据跨时钟域（四相握手，A 域 → B 域）
// 端口说明：
//   clk_a     ：源时钟域时钟
//   rst_a     ：源时钟域同步复位，高有效
//   src_valid ：源端要发送一个数据（单拍有效，和 src_data 同一拍给出）
//   src_data  ：要发送的数据（DW 位）
//   src_ready ：源端空闲，可以接收新的发送请求（为 1 时 src_valid 才会被接收）
//   clk_b     ：目的时钟域时钟（和 clk_a 没有固定的频率、相位关系，可能更快也可能更慢）
//   rst_b     ：目的时钟域同步复位，高有效
//   dst_valid ：目的端收到一个新数据（单拍，宽 1 个 clk_b 周期）
//   dst_data  ：目的端收到的数据，寄存器输出，dst_valid 那一拍起有效，保持到下一个数据到来
// 规格：
//   1. src_valid && src_ready 时，这个数据被接收，开始一次传输；src_ready 随即变 0，直到这次传输完全结束
//   2. src_ready=0 期间来的 src_valid 被忽略（数据丢弃，不影响正在进行的传输）
//   3. 采用四相握手：req↑ → ack↑ → req↓ → ack↓，四步都完成才算一次传输结束，src_ready 才回到 1
//   4. 传输期间送到 B 域的数据必须保持不变；数据本身不经过同步器
//   5. req 跨到 B 域、ack 跨到 A 域都必须用 sync_2ff，不能直接使用对方时钟域的信号
//   6. 每次传输，dst_valid 恰好出现 1 次、宽 1 个 clk_b 周期，dst_data 等于这次发送的数据
//   7. 无论 clk_a 比 clk_b 快还是慢都要正确
//   8. 复位：rst_a 有效后 src_ready=1；rst_b 有效后 dst_valid=0、dst_data=0（各时钟域用自己的复位）
`timescale 1ns / 1ps
module handshake_sync #(
  parameter DW = 8
) (
  input  wire          clk_a,
  input  wire          rst_a,
  input  wire          src_valid,
  input  wire [DW-1:0] src_data,
  output wire          src_ready,
  input  wire          clk_b,
  input  wire          rst_b,
  output reg          dst_valid,
  output reg [DW-1:0] dst_data
);
  // TODO：按上面的规格实现（输出端口的 wire/reg 类型可以按需要修改）
  //发送端信号
  reg req;
  wire sync_ack;
  reg [DW-1:0] reg_data;//因为src_data和src_valid只维持一拍，但是发送端到接收端需要多拍，所以需要存储
  //接收端信号
  reg ack;
  wire sync_req;
  //单比特传输信号连接同步器
  sync_2ff sync1(.clk(clk_a),.rst(rst_a),.d(ack),.q(sync_ack));//同步ack给发送端
  sync_2ff sync2(.clk(clk_b),.rst(rst_b),.d(req),.q(sync_req));//同步req给接收端 

  //发送端
  //注意将可以接收发送数据信号和可以发送数据的区别搞清楚
  assign src_ready = !req && !sync_ack;//四种状态只有第一种状态的时候表示可以接收发送数据信号
  always @(posedge clk_a) begin
    if(rst_a) begin
      //sync_ack已经在同步器中复位
      req<=1'b0;
    end
    else begin 
      //这一步要想明白，发送数据一共四个阶段
      //第一阶段表示没有发送数据：req=0，sync_ack=0，表示可以接收发送数据信号，req取决于src_valid信号
      //后面三个阶段都是在发送数据期间：req取决于是发送数据的哪个阶段，只有第二阶段需要置1(即req=1，sync_ack=0)，等待sync_ack信号变为1然后置0
      req<=(src_valid&&src_ready)||(req&&!sync_ack);
    end
  end
  //存储发送端数据
  always @(posedge clk_a) begin
    if(rst_a) begin
      reg_data<=0;
    end
    else begin
      if(src_valid&&src_ready) reg_data<=src_data;
      else reg_data<=reg_data;//保持即可
    end
  end
  
  //接收端
  always @(posedge clk_b) begin
    if(rst_b) begin
      //sync_req在同步器中复位
      ack<=1'b0;
    end
    else begin
      //接收数据其实也四个阶段
      //只有第二个阶段（ack=0,sync_req=1）和第三个阶段（ack=1,sync_req=1）需要置1
      ack<= sync_req; 
    end
  end
  //接收数据
  always @(posedge clk_b) begin
    if(rst_b) begin
      dst_data<=0;
      dst_valid<=1'b0;
    end
    else begin
      dst_valid <= sync_req && !ack;//valid信号需要和data信号同一拍
      if(sync_req && !ack) dst_data<=reg_data;//当sync_req=1，ack=0的时候需要更新数据
      else dst_data<=dst_data;//保持即可
    end
  end

endmodule
