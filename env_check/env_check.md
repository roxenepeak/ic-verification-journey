# xsim 功能验证清单

Vivado 版本：（填写，例如 2025.1）
测试日期：2026-10-17

|#|功能|文件|结果（能用 / 不能用）|备注（报错信息、退路）|
|-|-|-|-|-|
|1|UVM hello world（run\_test、+UVM\_TESTNAME）|hello\_uvm.sv|能用|2026-10-16 跑通|
|2|类、继承、virtual 方法、约束随机（dist、solve...before）|02\_class\_rand.sv|能用||
|3|covergroup + cross，xcrg 生成报告|03\_covergroup.sv + cov.bat|能用||
|4|并发断言 SVA + bind|04\_sva\_bind.sv|能用||
|5|代码覆盖率（statement/branch/condition/toggle）|05\_code\_cov.sv + cov.bat|能用||
|6|UVM 寄存器后门访问（hdl\_path）|06\_ral\_backdoor.sv|不能用|影响不大，有其他方式|

## 踩过的坑

* 新开的命令行窗口找不到 xvlog：要先 call settings64.bat（已写进 run.bat）

