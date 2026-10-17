@echo off
rem Usage: run.bat ^<file.sv^> ^<top^> [extra xsim args]
rem   run.bat 02_class_rand.sv tb
rem   run.bat hello_uvm.sv tb -testplusarg "UVM_TESTNAME=hello_test"
rem All generated files go into the work\ subfolder, sources stay clean.
set VIVADO_SETTINGS=E:\Xilinx\2025.2\Vivado\settings64.bat

call "%VIVADO_SETTINGS%" >nul
set SRC=%~f1
set SNAP=sim_%~n1
if not exist work mkdir work
pushd work
call xvlog -sv -L uvm "%SRC%" || goto :fail
call xelab %2 -L uvm -s %SNAP% -debug all || goto :fail
call xsim %SNAP% -R %3 %4 %5 %6
popd
goto :eof
:fail
popd
echo ======== COMPILE FAILED, see messages above ========
