@echo off
REM ==============================================================================
REM Batch script to run Vivado XSIM simulation for Catmull-Rom Cubic Resampler
REM ==============================================================================

set VIVADO_BIN=C:\Xilinx\Vivado\2023.2\bin
cd /d "%~dp0..\.."

echo [1/3] Compiling Catmull-Rom VHDL files with xvhdl...
call "%VIVADO_BIN%\xvhdl.bat" -2008 "HDL/cubic_catmull/cubic_catmull_core.vhd" "HDL/cubic_catmull/resampler_cubic_catmull.vhd" "HDL/cubic_catmull/tb_cubic_catmull.vhd"
if %ERRORLEVEL% neq 0 (
    echo Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [2/3] Elaborating simulation snapshot with xelab...
call "%VIVADO_BIN%\xelab.bat" -debug typical tb_cubic_catmull -s sim_catmull
if %ERRORLEVEL% neq 0 (
    echo Elaboration failed!
    exit /b %ERRORLEVEL%
)

echo [3/3] Running simulation with xsim...
call "%VIVADO_BIN%\xsim.bat" sim_catmull -R
if %ERRORLEVEL% neq 0 (
    echo Simulation failed!
    exit /b %ERRORLEVEL%
)

echo Simulation finished successfully! Output written to sim_data/vhdl_catmull.txt.

