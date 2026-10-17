@echo off
rem Coverage checks: functional coverage report for 03, code coverage for 05
rem All generated files and reports go into the work\ subfolder.
set VIVADO_SETTINGS=E:\Xilinx\2025.2\Vivado\settings64.bat
call "%VIVADO_SETTINGS%" >nul
if not exist work mkdir work
pushd work

echo ===== [03] functional coverage =====
call xvlog -sv ..\03_covergroup.sv
call xelab tb -s sim_fc
call xsim sim_fc -R
call xcrg -report_format html -dir xsim.covdb -report_dir fc_report

echo ===== [05] code coverage =====
call xvlog -sv ..\05_code_cov.sv
call xelab tb -s sim_cc -cc_type sbct -cc_db ccdb -cc_dir ./cc_dir
call xsim sim_cc -R
call xcrg -cc_db ccdb -cc_dir ./cc_dir -cc_report ./cc_report
popd
echo ===== done: reports are in work\fc_report and work\cc_report =====
