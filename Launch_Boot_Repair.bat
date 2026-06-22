@echo off
setlocal
cd /d "%~dp0"

:menu
cls
echo ============================================================
echo   WINDOWS BOOT PERFORMANCE REPAIR TOOLKIT
echo ============================================================
echo   1. Diagnose only
echo   2. Run safe repair set
echo   3. Restart Windows Explorer
echo   4. Rebuild icon cache
echo   5. Disable a non-Microsoft scheduled task
echo   6. Disable a current-user Run entry
echo   7. Run DISM RestoreHealth
echo   8. Run System File Checker
echo   0. Exit
echo ============================================================
set /p CHOICE=Select an option: 

if "%CHOICE%"=="1" set ARGS=&goto run
if "%CHOICE%"=="2" set ARGS=-RepairAllSafe&goto run
if "%CHOICE%"=="3" set ARGS=-RestartExplorer&goto run
if "%CHOICE%"=="4" set ARGS=-ClearIconCache&goto run
if "%CHOICE%"=="5" goto task
if "%CHOICE%"=="6" goto runentry
if "%CHOICE%"=="7" set ARGS=-RunDism&goto run
if "%CHOICE%"=="8" set ARGS=-RunSfc&goto run
if "%CHOICE%"=="0" goto end
goto menu

:task
set /p TASKPATH=Task path, for example \Vendor\ [default \]: 
if "%TASKPATH%"=="" set TASKPATH=\
set /p TASKNAME=Task name: 
set ARGS=-DisableScheduledTask -TaskPath "%TASKPATH%" -TaskName "%TASKNAME%"
goto run

:runentry
set /p RUNNAME=Current-user Run value name: 
set ARGS=-DisableCurrentUserRunEntry -RunValueName "%RUNNAME%"
goto run

:run
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1' -ErrorAction SilentlyContinue"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" %ARGS%
echo.
pause
goto menu

:end
endlocal
