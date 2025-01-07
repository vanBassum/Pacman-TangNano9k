@echo off
REM Generate GoWin compatible Verilog sources from the Pac-Man ROMs

for %%i in (pacman.5e pacman.5f pacman.6e pacman.6f pacman.6h pacman.6j 82s123.7f 82s126.1m 82s126.3m 82s126.4a) do (
    echo Converting ROM %%i
    python bin2v.py %%i
    if errorlevel 1 (
        echo Error occurred while converting %%i. Press any key to continue or Ctrl+C to exit.
        pause
    )
    echo.
)

echo Script completed. Press any key to close.
pause
