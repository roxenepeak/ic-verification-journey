// tb_pulse_sync.sv：pulse_sync 的自检查 testbench
// 用法（在 WSL 中执行）：
//   cd /mnt/e/ic_verif/stage1/03_pulse_sync && cmd.exe /c run.bat tb_pulse_sync 123
// 第 2 个参数是随机种子，tb 里用 +seed=N 读入
// 同时例化两个 pulse_sync：一个快时钟 → 慢时钟，一个慢时钟 → 快时钟，两个方向一起测
`timescale 1ns / 1ps
module tb_pulse_sync;

  localparam real T_FAST  = 10.0;  // 快时钟周期（ns）
  localparam real T_SLOW  = 27.0;  // 慢时钟周期（ns），故意不是快时钟的整数倍
  localparam int  MIN_GAP = 3;     // 相邻输入脉冲之间至少间隔多少个目的时钟周期

  logic clk_fast, clk_slow;
  logic rst_fast, rst_slow;

  // 方向 1：快 → 慢
  logic pulse_in_f2s, pulse_out_f2s;
  // 方向 2：慢 → 快
  logic pulse_in_s2f, pulse_out_s2f;
  //定义日志文件句柄和错误数量
  int fd;
  logic isError=0;//因为多个场景的错误也只算一个错误，所以只用一个一位信号判断即可
  //快到慢的统计变量
  int f2sPulseInCnt,f2sPulseOutCnt;//输入输出脉冲个数（用于比较两个脉冲数量是否匹配）
  real f2sFifo[$];//时间队列（用于存储输入脉冲到达时间的队列，输出时取出用于计算输入输出的延时）
  real f2sMaxlat=0,f2sMinlat=1e9;//最大延迟和最小延迟（输入和对应输出的延迟应该在2-3拍，用于记录是否在这个范围内）
  logic f2sPrePulseOut;//上一拍的输出（检查输出的宽度不能超过一个周期）
  logic f2sPulseOutIsValid=0;//用于判断输出宽度是否超过了一个周期
  real f2sT;//存储输入输出的延时
  //慢到快的统计变量
  int s2fPulseInCnt,s2fPulseOutCnt;
  real s2fFifo[$];
  real s2fMaxlat=0,s2fMinlat=1e9;
  logic s2fPrePulseOut;
  logic s2fPulseOutIsValid=0;
  real s2fT;

  pulse_sync dut_f2s (
    .clk_a  (clk_fast),
    .rst_a  (rst_fast),
    .pulse_a(pulse_in_f2s),
    .clk_b  (clk_slow),
    .rst_b  (rst_slow),
    .pulse_b(pulse_out_f2s)
  );

  pulse_sync dut_s2f (
    .clk_a  (clk_slow),
    .rst_a  (rst_slow),
    .pulse_a(pulse_in_s2f),
    .clk_b  (clk_fast),
    .rst_b  (rst_fast),
    .pulse_b(pulse_out_s2f)
  );

  // TODO：产生两个时钟（周期 T_FAST、T_SLOW）
  //两个forever不能放在一个initial块中，forever是死循环，会导致写在后面的forever永远无法执行
  initial begin
    clk_fast = 0;
    forever #(T_FAST/2.0) clk_fast = ~clk_fast;//注意#后面打括号，否则报错
  end
  initial begin
    clk_slow = 0;
    forever #(T_SLOW/2.0) clk_slow = ~clk_slow;
  end

  // TODO:由于是检查事件不是逐拍检查，所以需要编写监视器
  //快到慢的输入输出监视器（这里的复位时开始复位，不考虑中途复位的情况，中途复位需要将队列和计数情况）
  //输入监视器
  always @(posedge clk_fast) begin
    //输入是0的情况不处理即可，输入为1需要处理
    if(!rst_fast&&pulse_in_f2s) begin 
      f2sPulseInCnt++;//输入计数加1
      f2sFifo.push_back($realtime);//时间队列计入时间（ns）
    end
  end
  //输出监视器
  always @(posedge clk_slow) begin
    if(rst_slow) f2sPrePulseOut<=1'b0;
    else begin
      f2sPrePulseOut<=pulse_out_f2s;//存储当前拍输出
      if(pulse_out_f2s) begin 
        f2sPulseOutCnt++;//输出计数器加1 
        //检查输出是否超过一拍
        if(f2sPrePulseOut) f2sPulseOutIsValid<=1'b1;//如果输出出现两个连续1则不满足（不要置零，出现一次错误就是错误）
        //从时间队列中取出输入脉冲到达时间，然后用当前时间减去到达时间即可得到
        if(f2sFifo.size()) begin 
          f2sT = $realtime - f2sFifo.pop_front();
          //得到输入输出的最大延迟和最小延迟
          if(f2sT > f2sMaxlat*T_SLOW) f2sMaxlat=f2sT/T_SLOW;
          if(f2sT < f2sMinlat*T_SLOW) f2sMinlat=f2sT/T_SLOW;
        end
        else isError=1'b1;
      end
    end
  end

  //慢到快的输入输出监视器
  //输入监视器
  always @(posedge clk_slow) begin
    //输入是0的情况不处理即可，输入为1需要处理
    if(!rst_slow&&pulse_in_s2f) begin 
      s2fPulseInCnt++;//输入计数加1
      s2fFifo.push_back($realtime);//时间队列计入时间（ns）
    end
  end
  //输出监视器
  always @(posedge clk_fast) begin
    if(rst_fast) s2fPrePulseOut<=1'b0;
    else begin
      s2fPrePulseOut<=pulse_out_s2f;//存储当前拍输出
      if(pulse_out_s2f) begin
        s2fPulseOutCnt++;//输出计数器加1 
        //检查输出是否超过一拍
        if(s2fPrePulseOut) s2fPulseOutIsValid<=1'b1;//如果输出出现两个连续1则不满足
        //从时间队列中取出输入脉冲到达时间，然后用当前时间减去到达时间即可得到当前的输入输出延迟
        if(s2fFifo.size()) begin
          s2fT = $realtime - s2fFifo.pop_front();
          //得到输入输出的最大延迟和最小延迟
          if(s2fT > s2fMaxlat*T_FAST) s2fMaxlat=s2fT/T_FAST;
          if(s2fT < s2fMinlat*T_FAST) s2fMinlat=s2fT/T_FAST;
        end
        else isError=1'b1;
      end
    end
  end

  // TODO：判断模型是否正确
  task automatic check();
    // TODO：检查：每个方向输出脉冲和输出脉冲是否匹配
    //要满足队列为空并且输入输出计数器相同（其实前一种情况包含了后一种情况）
    if(f2sPulseInCnt!=f2sPulseOutCnt||f2sFifo.size()||s2fPulseInCnt!=s2fPulseOutCnt||s2fFifo.size()) 
      isError=1'b1;
    // TODO：检查：输入脉冲到输出脉冲的延迟不超过一个合理上限（大于三个时钟周期则错误）
    if(f2sMaxlat>3||s2fMaxlat>3) 
      isError=1'b1;
    if(f2sMinlat<=2||s2fMinlat<=2)//检查下限
      isError=1'b1;
    // TODO：检查：每个输出脉冲正好是 1 个目的时钟周期宽
    if(f2sPulseOutIsValid||s2fPulseOutIsValid) 
      isError=1'b1;
  endtask

  //TODO 编写激励task，发送输入脉冲信号（只持续1个源时钟周期）并保证和下一个脉冲之间有足够的间隔（按目的时钟周期计，不小于 MIN_GAP）
  task automatic sent_f2s(int gap);
    @(negedge clk_fast);pulse_in_f2s=1'b1;
    @(negedge clk_fast);pulse_in_f2s=1'b0;
    repeat(gap+1) @(negedge clk_slow);//每次修改后暂停4个时钟(暂停的是接收时钟域的时钟)（因为至少间隔3个时钟，但是clk_slow可能紧挨着clk_fast的下降沿，所以写成4个）
  endtask

  task automatic sent_s2f(int gap);
    @(negedge clk_slow);pulse_in_s2f=1'b1;
    @(negedge clk_slow);pulse_in_s2f=1'b0;
    repeat(gap+1) @(negedge clk_fast);//每次修改后暂停4个时钟
  endtask

  initial begin
    int seed = 1;
    // TODO：从 +seed=N 读入种子（不传用默认值）并打印；打开 sim_result.txt（追加）
    $value$plusargs("seed=%0d",seed);
    $display("seed=%0d",seed);
    process::self.srandom(seed);
    fd = $fopen("sim_result.txt","a");
    if(fd==0) $fatal(1,"打开日志文件失败");

    // TODO：两个时钟域分别复位，检查复位后两个输出都是 0
    rst_fast=1'b1;rst_slow=1'b1;pulse_in_f2s = 1'b0; pulse_in_s2f = 1'b0;//记得给输入
    fork
      repeat(2) @(posedge clk_slow);
      repeat(2) @(posedge clk_fast);
    join
    if(pulse_out_f2s!==1'b0||pulse_out_s2f!==1'b0) isError=1'b1;
    fork
      begin @(negedge clk_slow); rst_slow=1'b0;end
      begin @(negedge clk_fast); rst_fast=1'b0;end
    join

    // ---------------- 定向测试 ----------------
    // TODO：场景 1：每个方向只发 1 个脉冲，输出恰好 1 个脉冲、宽 1 个目的时钟周期
    fork
      sent_f2s(MIN_GAP);
      sent_s2f(MIN_GAP);
    join
    // TODO：场景 2：每个方向按正好 MIN_GAP 的间隔连续发多个脉冲，输出个数一致
    fork
      repeat(3) sent_f2s(MIN_GAP);
      repeat(3) sent_s2f(MIN_GAP);
    join
    // TODO：场景 3：长时间不发脉冲，输出一直为 0
    repeat (50) @(posedge clk_slow);
    
    // ---------------- 随机测试 ----------------
    // TODO：两个方向各发几百个脉冲，间隔随机但不小于 MIN_GAP 个目的时钟周期
    fork
      repeat(150) sent_f2s($urandom_range(MIN_GAP+5,MIN_GAP));
      repeat(200) sent_s2f($urandom_range(MIN_GAP+5,MIN_GAP));
    join
    repeat(10) @(posedge clk_slow);//注意要等待最后的脉冲传完
    
    //最后只用check一次即可
    check();
    // ---------------- 汇总 ----------------
    // TODO：打印并写进日志：种子、上面的统计；没有错误时打印 PASS（格式和 02_sync_fifo 一致）
    if(isError) begin
       //打印汇总
       $display("ERROR seed:%0d",seed);
       $fdisplay(fd,"ERROR seed:%0d",seed);
    end
    else begin
      $display("PASS seed:%0d",seed);//回归统计的时候只统计seed 
      $fdisplay(fd,"PASS seed:%0d",seed);
    end
    $display("f2sPulseInCnt:%0d,f2sPulseOutCnt:%0d,f2sMaxlat:%.2f,f2sMinlat:%.2f",f2sPulseInCnt,f2sPulseOutCnt,f2sMaxlat,f2sMinlat);
    $display("s2fPulseInCnt:%0d,s2fPulseOutCnt:%0d,s2fMaxlat:%.2f,s2fMinlat:%.2f",s2fPulseInCnt,s2fPulseOutCnt,s2fMaxlat,s2fMinlat);
    $fdisplay(fd,"f2sPulseInCnt:%0d,f2sPulseOutCnt:%0d,f2sMaxlat:%.2f,f2sMinlat:%.2f",f2sPulseInCnt,f2sPulseOutCnt,f2sMaxlat,f2sMinlat);
    $fdisplay(fd,"s2fPulseInCnt:%0d,s2fPulseOutCnt:%0d,s2fMaxlat:%.2f,s2fMinlat:%.2f",s2fPulseInCnt,s2fPulseOutCnt,s2fMaxlat,s2fMinlat);
    $fclose(fd);
    $finish;
  end
endmodule