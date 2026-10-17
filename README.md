# ic-verification-journey

数字 IC 验证学习记录（2026.10 起）。工具：Vivado xsim（Windows）+ WSL2 Ubuntu。

## 目录结构
| 目录 | 内容 |
|---|---|
| `env_check/` | xsim 功能验证清单：6 个小例子，结论见 `env_check/env_check.md` |

## 使用方法
- 仿真：进入对应文件夹，运行 `run.bat <源文件> <顶层模块>`，生成的文件都放在 `work\` 子文件夹里
- 清理：双击根目录的 `clean.bat`，删除所有仿真生成的文件，源代码不受影响
