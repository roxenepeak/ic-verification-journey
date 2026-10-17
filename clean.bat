@echo off
rem Delete every simulator-generated file under this folder. Source files are kept.
cd /d "%~dp0"
for /d /r %%d in (work xsim.dir xsim.covdb cc_dir fc_report cc_report .Xil) do if exist "%%d" rd /s /q "%%d"
del /s /q *.log *.jou *.pb *.wdb *.str dfx_runtime.txt hs_err_pid*.dmp hs_err_pid*.log webtalk*.* >nul 2>nul
echo ===== cleaned =====
pause
