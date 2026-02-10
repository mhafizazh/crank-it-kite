@echo off

echo ============================
echo Building Playdate Project...
echo ============================

pdc source Game.pdx

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed. Fix errors above.
    pause
    exit /b
)

echo.
echo ============================
echo Launching Simulator...
echo ============================

"C:\Users\mhafi\OneDrive\Documents\PlaydateSDK\bin\PlaydateSimulator.exe" "%CD%\Game.pdx"

echo.
echo Done.
