// spram.v：单口同步 RAM（参数化）
// 参数：
//   AW ：地址位宽，深度 = 2^AW
//   DW ：数据位宽
// 端口说明：
//   en    ：使能，高有效。en=0 时不读不写，rdata 保持不变
//   we    ：写使能，高有效（只在 en=1 时起作用）
//   addr  ：读写共用的地址
//   wdata ：写数据
//   rdata ：读数据，寄存器输出
// 规格：
//   1. en=1、we=1：在时钟上升沿把 wdata 写入 addr
//   2. en=1（不管 we）：在时钟上升沿把 addr 处的数据送到 rdata，读延迟 1 拍
//      （这一拍给出地址，下一个上升沿之后 rdata 才是这个地址的数据）
//   3. 读写共用一个地址，所以写的那一拍（en=1、we=1）也会读这个地址：
//      rdata 输出这个地址写之前的旧值
//   4. 没有复位：存储内容上电不确定，没写过的地址读出来是 X；rdata 在第一次读之前也是 X
module spram #(
  parameter AW = 4,
  parameter DW = 8
) (
  input  wire          clk,
  input  wire          en,//读使能
  input  wire          we,//写使能
  input  wire [AW-1:0] addr,
  input  wire [DW-1:0] wdata,
  output reg  [DW-1:0] rdata
);
  //先声明存储数组
  //也可以写成 mem[0:2**AW-1] **表示幂运算
  reg [DW-1:0] mem [0:(1<<AW)-1];

  // TODO：按上面的规格实现
  always @(posedge clk) begin 
    if(en&&we) mem[addr]<=wdata;//写入数据
    if(en) rdata<=mem[addr];//读取数据
  end

endmodule
