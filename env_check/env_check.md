# xsim 功能验证清单

Vivado 版本：2025.2
测试日期：2026-10-16 ～ 2026-10-18

| # | 功能 | 文件 | 结果 | 现象 / 备注 |
|---|---|---|---|---|
| 1 | UVM hello world（`run_test`、`+UVM_TESTNAME`） | `hello_uvm.sv` | 能用 | 打印 `UVM hello world!`，`-testplusarg "UVM_TESTNAME=hello_test"` 能切换 test |
| 2 | 类、继承、virtual 方法、约束随机（`dist`、`solve...before`、`randomize() with`） | `02_class_rand.sv` | 能用 | 20 次随机全部满足约束；父类句柄调用 virtual 方法得到子类结果（多态正确） |
| 3 | covergroup + cross，`xcrg` 生成报告 | `03_covergroup.sv` + `cov.bat` | 能用 | 功能覆盖率 100%，HTML 报告在 `work\fc_report` |
| 4 | 并发断言 SVA + `bind` | `04_sva_bind.sv` | 能用 | case 1 没有报错；case 2 正好报一次 `ASSERTION FAILED`，说明断言能正确抓到违例 |
| 5 | 代码覆盖率（statement / branch / condition / toggle） | `05_code_cov.sv` + `cov.bat` | 能用 | `xelab -cc_type sbct` 收集，`xcrg` 生成 HTML 报告；覆盖率不到 100% 符合预期（`op = 3` 的 default 分支故意没测） |
| 6 | UVM 寄存器后门访问（`hdl_path` 方式） | `06_ral_backdoor.sv` | 不能用 | `UVM_FATAL [UVM_HDL_READ] uvm_hdl DPI routines are compiled off`。原因：xsim 自带的 UVM 1.2 库编译时定义了 `UVM_HDL_NO_DPI`，`uvm_hdl_read/deposit` 等按路径字符串访问信号的 DPI 函数不可用，test 在 0 时刻直接 FATAL 退出（同一原因也导致 hello_uvm 里的 `[NO_DPI_TSTNAME]`、`[UVM/COMP/NAMECHECK]` 提示）。前门访问不受影响。退路：自己继承 `uvm_reg_backdoor`，在 `read` / `write` 里用层次化引用直接读写寄存器（路线 2.4 节，做项目二时实现） |

## 结论

- 后面所有阶段（SV 练手项目、UVM、DCache 项目）都可以只用 xsim 完成，暂时不需要 EDA Playground。
- 只有项目二（APB + RAL）的后门访问要用退路方案。

## 踩过的坑

- 新开的命令行窗口找不到 `xvlog`：要先 `call settings64.bat`（已写进 `run.bat`）。
- 终端行首是 `PS` 时是 PowerShell，不认识 `cd /d`，也跑不了 `call settings64.bat`：先输入 `cmd` 切换，或直接用 Anaconda Prompt。
- 传 UVM 参数时要加引号：`-testplusarg "UVM_TESTNAME=hello_test"`，因为 cmd 会把 `=` 当成分隔符。
- 仿真会生成很多中间文件：`run.bat` / `cov.bat` 已改成全部放进 `work\` 子文件夹，根目录的 `clean.bat` 可以一键清理。
