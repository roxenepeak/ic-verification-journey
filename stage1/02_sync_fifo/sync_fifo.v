// sync_fifo.v：同步 FIFO（参数化，单时钟）
// 参数：
//   DW ：数据位宽
//   AW ：地址位宽，深度 DEPTH = 2^AW
// 端口说明：
//   clk   ：时钟，读写共用
//   rst   ：同步复位，高有效
//   wr_en ：写请求，高有效
//   wdata ：写数据
//   rd_en ：读请求，高有效
//   rdata ：读数据，寄存器输出
//   full  ：满标志，FIFO 里有 DEPTH 个数据时为 1
//   empty ：空标志，FIFO 里没有数据时为 1
//   count ：FIFO 里当前的数据个数（0 ~ DEPTH，所以是 AW+1 位）
// 规格：
//   1. 写：wr_en=1 且 full=0 时，在时钟上升沿把 wdata 写进 FIFO；full=1 时写请求被忽略（即使同一拍有读）
//   2. 读：rd_en=1 且 empty=0 时，在时钟上升沿把最早写入的数据送到 rdata，读延迟 1 拍；
//      empty=1 时读请求被忽略（即使同一拍有写），rdata 保持不变；没有成功读的拍 rdata 也保持不变
//   3. 非空非满时同一拍读写：读和写都成功，count 不变
//   4. full、empty、count 都是“这一拍上升沿之后”FIFO 的状态，在上升沿后更新
//   5. 复位：FIFO 清空（empty=1、full=0、count=0），rdata 清 0
`timescale 1ns / 1ps  
module sync_fifo #(
  parameter DW = 8,
  parameter AW = 3
) (
  input  wire          clk,
  input  wire          rst,
  input  wire          wr_en,
  input  wire [DW-1:0] wdata,
  input  wire          rd_en,
  output reg  [DW-1:0] rdata,
  output wire           full,
  output wire          empty,
  output reg [AW:0]   count
);

  // TODO：用计数器法按上面的规格实现
  
  //定义存储器和读写指针
  reg [DW-1:0] mem [0:2**AW-1];
  reg [AW-1:0] rPtr,wPtr;//采用的是计数器法

  //判断空或满
  assign empty = (count==0);
  assign full = (count==2**AW);

  //读写操作和复位操作，注意不能放在三个always中处理，一个变量只能在一个always块中赋值
  always @(posedge clk) begin
    //复位操作
    if(rst) begin
      rPtr<='0;
      wPtr<='0;
      count<=0;
      rdata<=0;
    end 
    else begin//不执行复位操作才能执行者三个模块
      //读操作
      if(rd_en&&!empty) begin
        rdata<=mem[rPtr];
        rPtr<=rPtr+1;
        if(rPtr==2**AW-1)//循环存储（其实可以不写，超过位宽的自动舍去了，和软件不同）
          rPtr<='0;
        count<=count-1;
      end
      //写操作
      if(wr_en&&!full) begin
        mem[wPtr]<=wdata;
        wPtr<=wPtr+1;
        if(wPtr==2**AW-1)
          wPtr<='0;
        count<=count+1;
      end
      //注意还有同时读写的操作，这里只用操作count即可，写在最后保证覆盖前面的赋值
      if(wr_en&&rd_en&&!empty&&!full)
        count<=count;
    end
  end
endmodule
