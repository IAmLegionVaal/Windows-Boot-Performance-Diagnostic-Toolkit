@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1' -ErrorAction SilentlyContinue"

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

if "%CHOICE%"=="1" goto diagnose
if "%CHOICE%"=="2" goto safe
if "%CHOICE%"=="3" goto explorer
if "%CHOICE%"=="4" goto iconcache
if "%CHOICE%"=="5" goto task
if "%CHOICE%"=="6" goto runentry
if "%CHOICE%"=="7" goto dism
if "%CHOICE%"=="8" goto sfc
if "%CHOICE%"=="0" goto end
goto menu

:diagnose
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1"
goto complete

:safe
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -RepairAllSafe
goto complete

:explorer
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -RestartExplorer
goto complete

:iconcache
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -ClearIconCache
goto complete

:task
set /p TASKPATH=Task path, for example \Vendor\ [default \]: 
if "%TASKPATH%"=="" set TASKPATH=\
set /p TASKNAME=Task name: 
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -DisableScheduledTask -TaskPath "%TASKPATH%" -TaskName "%TASKNAME%"
goto complete

:runentry
set /p RUNNAME=Current-user Run value name: 
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -DisableCurrentUserRunEntry -RunValueName "%RUNNAME%"
goto complete

:dism
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -RunDism
goto complete

:sfc
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows_Boot_Performance_Repair_Toolkit.ps1" -RunSfc
goto complete

:complete
echo.
pause
goto menu

:end
endlocal
