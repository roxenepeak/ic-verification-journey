@echo off
setlocal enabledelayedexpansion
rem 用法：run.bat ^<顶层模块名^> [随机种子] [传给 xsim 的其他参数]
rem   要编译的源文件写在 files.f 里，一行一个，按编译顺序排列
rem   例：run.bat tb_spram        不传种子
rem       run.bat tb_spram 123    种子为 123，传给 xsim 的是 -testplusarg seed=123
rem   所有仿真生成的文件都放在 work 子文件夹里
set VIVADO_SETTINGS=E:\Xilinx\2025.2\Vivado\settings64.bat
call "%VIVADO_SETTINGS%" >nul
set SRCS=
for /f "usebackq delims=" %%f in ("%~dp0files.f") do set SRCS=!SRCS! "%~dp0%%f"
set PLUSARGS=
if not "%~2"=="" set PLUSARGS=-testplusarg "seed=%~2"
if not exist "%~dp0work" mkdir "%~dp0work"
pushd "%~dp0work"
call xvlog -sv -L uvm !SRCS! || goto :fail
call xelab %1 -L uvm -s sim_%1 -debug all || goto :fail
call xsim sim_%1 -R !PLUSARGS! %3 %4 %5
popd
goto :eof
:fail
popd
echo ======== 编译失败，请看上面的报错信息 ========
