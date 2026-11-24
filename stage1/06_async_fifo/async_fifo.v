// async_fifo.v：参数化异步 FIFO（写、读在两个互不相关的时钟域）
// 参数：
//   DW ：数据位宽
//   AW ：地址位宽，深度 DEPTH = 2^AW
// 端口说明：
//   写时钟域：
//     wclk  ：写时钟
//     wrst  ：写域同步复位，高有效
//     wr_en ：写请求，为 1 且 full=0 的那一拍把 wdata 写入 FIFO
//     wdata ：写数据
//     full  ：满标志（在写时钟域产生）
//   读时钟域：
//     rclk  ：读时钟（和 wclk 没有固定的频率、相位关系，可能更快也可能更慢）
//     rrst  ：读域同步复位，高有效
//     rd_en ：读请求，为 1 且 empty=0 的那一拍读出一个数据
//     rdata ：读数据，寄存器输出，在读成功那一拍之后的下一拍有效
//     empty ：空标志（在读时钟域产生）
// 规格：
//   1. 写成功 = wr_en && !full；full=1 时写请求被忽略，数据不进 FIFO
//   2. 读成功 = rd_en && !empty；empty=1 时读请求被忽略；没有读成功的拍 rdata 保持不变
//   3. 数据先进先出，不丢、不重复、不乱序
//   4. 读写指针都是 AW+1 位；指针跨时钟域前必须转成格雷码，且格雷码必须是寄存器输出
//   5. 格雷码指针的每一位都用 sync_2ff 同步到对方时钟域，不能直接使用对方时钟域的信号
//   6. full 只能在写域用“自己的写指针 + 同步过来的读指针”判断；empty 只能在读域用“自己的读指针 + 同步过来的写指针”判断
//   7. full / empty 允许偏保守（假满、假空），但绝不能在真满时 full=0、真空时 empty=0
//   8. 两边都停止读写后，几个周期内 full / empty 必须反映真实状态（不能一直卡在假满、假空）
//   9. full、empty 用组合输出还是寄存器输出由你决定
//  10. 复位：wrst 有效后写域清零、full=0；rrst 有效后读域清零、empty=1、rdata=0（各时钟域用自己的复位）
//  11. 存储体用模块内部的寄存器数组实现（wclk 写、rclk 读），不用 IP
`timescale 1ns / 1ps
module async_fifo #(
  parameter DW = 8,
  parameter AW = 4
) (
  // 写时钟域
  input  wire          wclk,
  input  wire          wrst,
  input  wire          wr_en,
  input  wire [DW-1:0] wdata,
  output wire          full,
  // 读时钟域
  input  wire          rclk,
  input  wire          rrst,
  input  wire          rd_en,
  output reg [DW-1:0] rdata,
  output wire          empty
);
  // TODO：按上面的规格实现（输出端口的 wire/reg 类型可以按需要修改）
  
  //定义参数和存储器
  reg [DW-1:0] ram[0:2**AW-1];
  reg [AW:0] wbin,rbin;//读写指针的二进制表示
  wire [AW:0] wgray,rgray;//读写指针的格雷码表示
  reg [AW:0] final_wgray,final_rgray;//寄存器输出的格雷码表示（防止同步器采集到组合逻辑的毛刺）
  wire [AW:0] sync_wgray,sync_rgray;//同步后的格雷码表示的读写指针
  //读时钟域
  bin2gray #(.W(AW+1)) rmod(.bin(rbin),.gray(rgray));//将读写指针的二进制表示转换为格雷码表示
  assign empty = (sync_wgray == rgray);//在读域判空，写指针等于读指针(直接用格雷码判断，不用将同步过来的格雷码转为二进制)
  always @(posedge rclk) begin
    if(rrst) begin 
      rdata<=0;
      rbin<=0;
      //写指针在同步器中复位
    end
    //读取数据
    else if(rd_en&&!empty)begin 
      rdata<= ram[rbin[AW-1:0]];//格雷码只是为了保证多指针域传输，地址还是用二进制
      rbin<=rbin+1;//不要用rbin++,是阻塞赋值，可能导致rgray出现竞争
    end
  end
  //寄存器输出格雷码给同步器
  always @(posedge rclk) begin
    if(rrst) final_rgray<=0;
    else final_rgray<=rgray;
  end
  //将读指针通过同步器同步到写时钟域
  genvar i;
  generate
    for(i=0;i<AW+1;i=i+1) begin:rsync_nums
      sync_2ff rsync(.clk(wclk),.rst(wrst),.d(final_rgray[i]),.q(sync_rgray[i]));
    end
  endgenerate
  
  //写时钟域
  bin2gray #(.W(AW+1)) wmod(.bin(wbin),.gray(wgray));
  assign full = ((wgray[AW:AW-1] ^ sync_rgray[AW:AW-1])==2'b11) && (wgray[AW-2:0]==sync_rgray[AW-2:0]);//高两位互补，其他位相等
  always @(posedge wclk) begin
    if(wrst) begin
      wbin<=0;
      //读指针在同步器中复位
    end
    //写入数据
    else if(wr_en&&!full) begin
      ram[wbin[AW-1:0]] <= wdata;
      wbin<=wbin+1'b1;
    end
  end
  //寄存器输出格雷码给同步器
  always @(posedge wclk) begin
    if(wrst) final_wgray<=0;
    else final_wgray<=wgray;
  end
  //将写指针通过同步器同步到读时钟域
  generate
    for(i=0;i<AW+1;i=i+1) begin:wsync_nums
      sync_2ff wsync(.clk(rclk),.rst(rrst),.d(final_wgray[i]),.q(sync_wgray[i]));
    end
  endgenerate
endmodule
