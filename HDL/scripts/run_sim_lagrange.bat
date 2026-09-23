@echo off
REM ==============================================================================
REM Batch script to run Vivado XSIM simulation for Lagrange 4-Point Cubic Resampler
REM ==============================================================================

set VIVADO_BIN=C:\Xilinx\Vivado\2023.2\bin
cd /d "%~dp0..\.."

echo [1/3] Compiling Lagrange VHDL files with xvhdl...
call "%VIVADO_BIN%\xvhdl.bat" -2008 "HDL/cubic_lagrange/cubic_lagrange_core.vhd" "HDL/cubic_lagrange/resampler_cubic_lagrange.vhd" "HDL/cubic_lagrange/tb_cubic_interpolator.vhd"
if %ERRORLEVEL% neq 0 (
    echo Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [2/3] Elaborating simulation snapshot with xelab...
call "%VIVADO_BIN%\xelab.bat" -debug typical tb_cubic_interpolator -s sim_lagrange
if %ERRORLEVEL% neq 0 (
    echo Elaboration failed!
    exit /b %ERRORLEVEL%
)

echo [3/3] Running simulation with xsim...
call "%VIVADO_BIN%\xsim.bat" sim_lagrange -R
if %ERRORLEVEL% neq 0 (
    echo Simulation failed!
    exit /b %ERRORLEVEL%
)

echo Simulation finished successfully! Output written to sim_data/vhdl_lagrange.txt.

