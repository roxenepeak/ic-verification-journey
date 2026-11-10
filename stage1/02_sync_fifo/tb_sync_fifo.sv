// tb_sync_fifo.sv：sync_fifo 的自检查 testbench
// 用法（在 WSL 中执行）：
//   cd /mnt/e/ic_verif/stage1/02_sync_fifo && cmd.exe /c run.bat tb_sync_fifo 123
// 第 2 个参数是随机种子，tb 里用 +seed=N 读入
`timescale 1ns / 1ps
module tb_sync_fifo;

  localparam DW    = 8;
  localparam AW    = 3;
  localparam DEPTH = 1 << AW;

  logic          clk;
  logic          rst;
  logic          wr_en;
  logic [DW-1:0] wdata;
  logic          rd_en;
  logic [DW-1:0] rdata;
  logic          full;
  logic          empty;
  logic [  AW:0] count;

  sync_fifo #(
      .DW(DW),
      .AW(AW)
  ) dut (
      .clk  (clk),
      .rst  (rst),
      .wr_en(wr_en),
      .wdata(wdata),
      .rd_en(rd_en),
      .rdata(rdata),
      .full (full),
      .empty(empty),
      .count(count)
  );
  int errorCnt=0;
  int checkCnt=0;
  int expModelErrorCnt=0;
  int fd;

  // TODO：参考模型（和 DUT 写法不同），给出期望的 rdata、full、empty、count
  //定义存储器，读写指针和期望的输出
  reg [DW-1:0] mem[0:DEPTH-1];
  reg [AW:0]
      rPtr,
      wPtr;//参考模型采用的是指针扩展位法而不是计数器法（指针位数需要比深度多一位）
  reg [DW-1:0] expRdata;
  reg expFull, expEmpty;
  reg [AW:0] expCount;//虽然采用的是指针扩展位法但是还是要定义计数器，用于和设计模型的计数器比较
  //判断空或满
  assign expEmpty = (rPtr == wPtr);
  assign expFull  = (rPtr[AW] != wPtr[AW]) && (rPtr[AW-1:0] == wPtr[AW-1:0]);
  //读写操作和复位操作
  always @(posedge clk) begin
    //复位操作
    if (rst) begin
      rPtr<=0;
      wPtr<=0;
      expRdata<=0;
      expCount<=0;
    end
    else begin
      //读操作
      if(rd_en&&!expEmpty) begin
        expRdata<=mem[rPtr[AW-1:0]];
        rPtr<=rPtr+1;
        expCount<=expCount-1;
      end
      //写操作
      if(wr_en&&!expFull) begin
        mem[wPtr[AW-1:0]]<=wdata;
        wPtr<=wPtr+1;
        expCount<=expCount+1;
      end
      //读写操作同时进行
      if(wr_en&&rd_en&&!expFull&&!expEmpty)
        expCount<=expCount;
    end
  end

  // TODO：产生时钟
  initial clk = 0;
  always #5 clk = ~clk;

  // TODO：检查任务：比较 DUT 输出和期望值，统计检查次数和错误数，错误信息同时写进日志
  task check(logic [DW-1:0] handRdata,logic handFull,logic handEmpty,logic [AW:0] handCount);
    if(handRdata!=rdata||handFull!=full||handEmpty!=empty||handCount!=count) begin
      errorCnt++;
      //字段太多了，不写具体字段对比了
      $display("time:%0t,errorCnt:%0d",$time,errorCnt);
      //check中也需要写入文件，这个内容不会被parse_result.py这个脚本解析，这个脚本只解析汇总行
      $fdisplay(fd,"time:%0t,errorCnt:%0d",$time,errorCnt);
    end
    if(handRdata!=expRdata||handFull!=expFull||handEmpty!=expEmpty||handCount!=expCount) begin
      expModelErrorCnt++;
      $display("time:%0t,expModelErrorCnt:%0d",$time,expModelErrorCnt);
      $fdisplay(fd,"time:%0t,expModelErrorCnt:%0d",$time,expModelErrorCnt);
    end
    checkCnt++;
  endtask


  initial begin
    int i;
    int wrPassCnt = 0;
    int rdPassCnt = 0;
    int jumpFullCnt = 0;
    int jumpEmptyCnt = 0;
    int wrAndrdPassCnt = 0;
    int fillFIFOCnt = 0;
    int temp = 0;
    // TODO：从 +seed=N 读入种子（不传用默认值）并打印；打开 sim_result.txt（追加）
    int seed = 1;//设置默认种子
    $value$plusargs("seed=%0d",seed);//从命令行读取种子
    $display("seed=%0d",seed);//打印当前种子
    process::self.srandom(seed);
    //打开日志文件（在02下面中的work目录中）
    fd = $fopen("sim_result.txt","a");
    if(fd==0) $fatal(1,"sim_result.txt文件打开失败");

    // TODO：复位，检查复位后的状态
    rst=1'b1;wr_en=1'b0;wdata=0;rd_en=1'b0;
    repeat(2) @(posedge clk);
    @(negedge clk);
    rst=1'b0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b1,0);

    // ---------------- 定向测试（期望值用手算的字面值，同时和参考模型对照） ----------------
    // TODO：场景 1：连续写满 DEPTH 个数，检查 count 逐个加 1、写完最后一个后 full=1
    for(i=0;i<DEPTH;i++) begin
      @(negedge clk);
      rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=i;
      @(posedge clk);
      #1;
      if(i!=DEPTH-1)
        check(0,1'b0,1'b0,i+1);
      else
        check(0,1'b1,1'b0,DEPTH);
    end

    // TODO：场景 2：满时继续写，写请求被忽略，FIFO 内容和 count 不变
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=1;//不能用0，因为当前mem[0]=0
    @(posedge clk);
    #1;
    check(0,1'b1,1'b0,DEPTH);

    // TODO：场景 3：连续读空，检查读出顺序和写入顺序一致、读完最后一个后 empty=1
    for(i=0;i<DEPTH;i++) begin
      @(negedge clk);
      rst=1'b0;wr_en=1'b0;rd_en=1'b1;wdata=0;
      @(posedge clk);
      #1;
      if(i!=DEPTH-1)
        check(i,1'b0,1'b0,DEPTH-i-1);
      else
        check(i,1'b0,1'b1,0);
    end
    
    // TODO：场景 4：空时继续读，读请求被忽略，rdata 保持
    @(negedge clk);
    rst=1'b0;wr_en=1'b0;rd_en=1'b1;wdata=0;
    @(posedge clk);
    #1;
    check(DEPTH-1,1'b0,1'b1,0);
    
    // TODO：场景 5：非空非满时同一拍读写，读写都成功、count 不变
    //由于上一拍为空，所以先写入一个再测试
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=0;
    @(posedge clk);
    #1;
    check(DEPTH-1,1'b0,1'b0,1);
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b1;wdata=0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b0,1);

    // TODO：场景 6：满时同一拍读写（能读出）、空时同一拍读写（能写入），结果符合规格第 1、2 条
    //由于上一拍有一个，先读出
    @(negedge clk);
    rst=1'b0;wr_en=1'b0;rd_en=1'b1;wdata=0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b1,0);
    //现在为空，测试同一拍读写能写入
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b1;wdata=0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b0,1);
    //对其写满
    for(i=1;i<DEPTH;i++) begin
      @(negedge clk);
      rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=i;
      @(posedge clk);
      #1;
      if(i!=DEPTH-1)
        check(0,1'b0,1'b0,i+1);
      else 
        check(0,1'b1,1'b0,DEPTH);
    end
    //现在为满，测试同一拍读写能读出
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b1;wdata=0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b0,DEPTH-1);

    // TODO：场景 7：写读总数超过 DEPTH 的多倍，检查指针回绕后数据仍然正确
    //上一拍是写满了后读出了一个
    //场景7这样测试：复位后先写 3 个数，再连续 3*DEPTH 拍同时读写（第 k 拍写入 k+3），检查每拍都读出 k 且 count 一直是 3，最后剩三个数不用读出，给场景8测试
    //复位
    @(negedge clk);
    rst=1'b1;wr_en=1'b0;rd_en=1'b0;wdata=0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b1,0);
    //先写入三个数
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=1;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b0,1);
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=2;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b0,2);
    @(negedge clk);
    rst=1'b0;wr_en=1'b1;rd_en=1'b0;wdata=3;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b0,3);
    //连续读写3*DEPTH拍
    for(i=0;i<3*DEPTH-1;i++) begin
      @(negedge clk);
      rst=1'b0;wr_en=1'b1;rd_en=1'b1;wdata=i+4;
      @(posedge clk);
      #1;
      check(i+1,1'b0,1'b0,3);
    end
    
  

    // TODO：场景 8：FIFO 里有数据时复位，复位后为空
    @(negedge clk);
    rst=1'b1;wr_en=1'b0;rd_en=1'b0;wdata=0;
    @(posedge clk);
    #1;
    check(0,1'b0,1'b1,0);

    // ---------------- 随机测试 ----------------
    // TODO：随机 3000 拍，wr_en、rd_en 随机，和参考模型逐拍比较
    // TODO：统计：成功写次数、成功读次数、满时写被忽略次数、空时读被忽略次数、同一拍读写都成功的次数、FIFO 变满的次数
    repeat(3000) begin
      @(negedge clk);
      rst=1'b0;wr_en=$urandom();rd_en=$urandom();wdata=$urandom();  
      //注意统计次数需要写在上升沿前，因为满和空会在上升沿改变
      //如果写在上升沿后可能出现的情况：当前拍是写入，写入后FIFO为满，会导致当前拍写入未能计数
      if(wr_en&&!expFull) wrPassCnt++;
      if(rd_en&&!expEmpty) rdPassCnt++;
      if(wr_en&&expFull) jumpFullCnt++;
      if(rd_en&&expEmpty) jumpEmptyCnt++;
      if(wr_en&&rd_en&&!expFull&&!expEmpty) wrAndrdPassCnt++;
      if(!expFull) temp = 1; else temp=0;//如果不满则先记录
      @(posedge clk);
      #1;
      if(temp&&expFull) fillFIFOCnt++;//如果在上升沿之后满了则说明是变满
      check(expRdata,expFull,expEmpty,expCount);
      
    end
    // ---------------- 汇总 ----------------
    // TODO：打印并写进日志：种子、检查次数、错误数、上面的统计；没有错误时打印 PASS（格式和 01_spram 一致，parse_result.py 能解析）
    if(errorCnt||expModelErrorCnt) begin
      $display("ERROR seed:%0d,checkCnt:%0d,errorCnt:%0d,expModelErrorCnt:%0d,wrPassCnt:%0d,rdPassCnt:%0d,jumpFullCnt:%0d,jumpEmptyCnt:%0d,wrAndrdPassCnt:%0d,fillFIFOCnt:%0d",seed,checkCnt,errorCnt,expModelErrorCnt,wrPassCnt,rdPassCnt,jumpFullCnt,jumpEmptyCnt,wrAndrdPassCnt,fillFIFOCnt);
      $fdisplay(fd,"ERROR seed:%0d,checkCnt:%0d,errorCnt:%0d,expModelErrorCnt:%0d,wrPassCnt:%0d,rdPassCnt:%0d,jumpFullCnt:%0d,jumpEmptyCnt:%0d,wrAndrdPassCnt:%0d,fillFIFOCnt:%0d",seed,checkCnt,errorCnt,expModelErrorCnt,wrPassCnt,rdPassCnt,jumpFullCnt,jumpEmptyCnt,wrAndrdPassCnt,fillFIFOCnt);
    end
    else begin
      $display("PASS seed:%0d,checkCnt:%0d,wrPassCnt:%0d,rdPassCnt:%0d,jumpFullCnt:%0d,jumpEmptyCnt:%0d,wrAndrdPassCnt:%0d,fillFIFOCnt:%0d",seed,checkCnt,wrPassCnt,rdPassCnt,jumpFullCnt,jumpEmptyCnt,wrAndrdPassCnt,fillFIFOCnt);
      $fdisplay(fd,"PASS seed:%0d,checkCnt:%0d,wrPassCnt:%0d,rdPassCnt:%0d,jumpFullCnt:%0d,jumpEmptyCnt:%0d,wrAndrdPassCnt:%0d,fillFIFOCnt:%0d",seed,checkCnt,wrPassCnt,rdPassCnt,jumpFullCnt,jumpEmptyCnt,wrAndrdPassCnt,fillFIFOCnt);
    end
    $fclose(fd);
    $finish;
  end
endmodule
