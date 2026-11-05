// tb_spram.sv：单口同步 RAM 的自检查 testbench（定向向量从文件读入 + 随机）
module tb_spram;
  localparam AW = 4;
  localparam DW = 8;

  logic          clk;
  logic          en, we;
  logic [AW-1:0] addr;
  logic [DW-1:0] wdata;
  logic [DW-1:0] rdata;

  reg [DW-1:0] exp_mem [0:2**AW-1];//标准ram模型的存储元
  logic[DW-1:0] expRdata;//标准ram模型的读出数据
  int errCnt = 0;//错误次数
  int checkCnt = 0;//检查次数
  int fd;//文件句柄
  logic [DW-1:0] handExpRdata;//用于定向测试传入的期望值
  int readCnt = 0;//读的次数
  int writeCnt = 0;//写的次数
  int readPreAddrCnt = 0;//记录这一拍读上一拍写入的次数
  reg [AW-1:0] preAddr;//存储上一拍操作的地址
  reg preEn,preWe;//存储上一拍的操作


  // TODO：实例化 spram（参数用上面的 AW、DW）
  spram #(.AW(AW),.DW(DW)) dut(.clk(clk),.en(en),.we(we),.addr(addr),.wdata(wdata),.rdata(rdata));

  // TODO：产生时钟，周期 10ns
  initial clk = 0;
  always #5 clk = ~clk;

  // ---------- 参考模型 ----------
  // TODO：在 tb 里独立实现一个 RAM 模型，给出每拍的期望 rdata
  always @(posedge clk) begin
    if(en&&we) exp_mem[addr]<=wdata;
    if(en) expRdata<=exp_mem[addr];
  end

  // ---------- 检查 ----------
  // TODO：check task：
  //       1. DUT 和期望值比较，不一致打印错误信息（时间、期望值、实际值）并计数
  //       2. 错误信息同时写进日志文件 sim_result.txt
  //       3. 统计检查次数
  task check(logic [DW-1:0] handExpRdata);
    //打开文件可以放在initial中，fd是全局变量
    if(rdata!==expRdata||rdata!==handExpRdata) begin 
      errCnt++;
      $display("time=%0t,rdata=%0d,expRdata=%0d,handExpRdata=%0d",$time,rdata,expRdata,handExpRdata);
      $fdisplay(fd,"time=%0t,rdata=%0d,expRdata=%0d,handExpRdata=%0d",$time,rdata,expRdata,handExpRdata);
    end
    checkCnt++;
  endtask
  // ---------- 驱动 ----------
  initial begin
    //创建数组存储vectors.hex读出来的内容 
    //这里we和en虽然是一位信号，但是后面用readmemh读入数组，所以需要用4位16进制存储
    reg [27:0] vec [0:255];//最多256个定向测试 0-7是handExpRdata,8-15是wdata，16-19是addr,20是we,24是en
    int i;//用于遍历vec数组进行定向测试

    // TODO：从命令行读入种子（+seed=N），没传时用默认值；打印本次用的种子，并让随机数从这个种子开始
    int seed = 1;//默认值
    $value$plusargs("seed=%d",seed);//用于接收命令行传入的种子
    $display("seed=%0d",seed);//打印当前使用的种子
    //用种子设置当前线程的随机生成器（必须在第一次调用 $urandom 之前）
    process::self().srandom(seed);

    // TODO：打开日志文件 sim_result.txt
    fd = $fopen("sim_result.txt","a");//打开文件，没有就创建
    if(fd==0) $fatal(1,"sim_result.txt 打开失败");
    
    // TODO：0 时刻初始化所有输入
    en=1'b0;we=1'b0;addr='b0;wdata='b0;//注意不能写成AW'b0

    // ---------- 定向：测试向量从 vectors.hex 读入 ----------
    // TODO：用 $readmemh 读入 vectors.hex，逐条驱动 DUT 并检查，期望值用向量里手算的字面量
    //       向量条数以文件为准：往 vectors.hex 里增删向量，不需要改 tb
    //       定向阶段同时用手算期望值检查参考模型
    //       向量要覆盖的场景：（见vectors.hex）
    //         1. 写几个地址再读回，包括地址 0 和最大地址
    //         2. 同一地址先后写两次，读出后写的值
    //         3. 写的那一拍，rdata 是这个地址写之前的旧值
    //         4. en=0 时写不生效、rdata 保持
    //         5. 每拍换一个地址连续读，每拍都对
    //读入数组的地址："E:\ic_verif\stage1\01_spram\vectors.hex"
    $readmemh("E:/ic_verif/stage1/01_spram/vectors.hex", vec);   // 路径用/,\会被识别会转义字符
    for(i=0;i<256;i++) begin
      //判断什么时候退出
      if ($isunknown(vec[i][27:24])) break;   // en 字段是 x：文件里的向量用完了
      @(negedge clk);
      handExpRdata = vec[i][7:0];
      wdata = vec[i][15:8];
      addr = vec[i][19:16];
      we = vec[i][20];
      en = vec[i][24];
      @(posedge clk);
      #1;
      check(handExpRdata);//检查
    end
    

    // ---------- 随机：2000 拍 ----------
    // TODO：en、we、addr、wdata 随机，用参考模型做期望值，每拍检查
    //       统计：写次数（en=1、we=1）、只读次数（en=1、we=0）、写完紧接着下一拍读同一地址的次数
    repeat(2000) begin 
      @(negedge clk);
      en = $urandom();
      we = $urandom();
      addr = $urandom();
      wdata = $urandom();
      if(en&&we) writeCnt++;
      if(en&&~we) readCnt++;
      if(preAddr===addr&&preEn&&preWe&&en&&!we) readPreAddrCnt++;
      preAddr=addr;
      preEn=en;
      preWe=we;
      @(posedge clk);
      #1;
      check(expRdata);
    end

    // ---------- 汇总 ----------
    // TODO：打印并写进日志：种子、检查次数、错误数、随机阶段的三个统计；没有错误时打印 PASS
    //       要求：同一个种子跑两次，结果完全一样；换一个种子，统计数字会变
    if(errCnt) begin
      $display("ERROR errCnt:%0d seed:%0d checkCnt:%0d writeCnt:%0d readCnt:%0d readPreAddrCnt:%0d",errCnt,seed,checkCnt,writeCnt,readCnt,readPreAddrCnt);
      $fdisplay(fd,"ERROR errCnt:%0d seed:%0d checkCnt:%0d writeCnt:%0d readCnt:%0d readPreAddrCnt:%0d",errCnt,seed,checkCnt,writeCnt,readCnt,readPreAddrCnt);
    end
    else begin
      $display("PASS seed:%0d checkCnt:%0d writeCnt:%0d readCnt:%0d readPreAddrCnt:%0d",seed,checkCnt,writeCnt,readCnt,readPreAddrCnt);
      $fdisplay(fd,"PASS seed:%0d checkCnt:%0d writeCnt:%0d readCnt:%0d readPreAddrCnt:%0d",seed,checkCnt,writeCnt,readCnt,readPreAddrCnt);
    end
    $fclose(fd);//记得关闭文件
    $finish;
  end
endmodule
