@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------------------
rem pull_fgo.bat - pull specific FGO save files from Android /Android/data via adb
rem
rem FGO's /Android/data/com.aniplex.fategrandorder.en folder is ~5.8 GB, so
rem pulling the whole thing is slow and mostly pointless. These four small files
rem under files/data are the ones that usually matter (account / transfer data).
rem
rem Usage:
rem   pull_fgo.bat                     pull the default 4 files into fgo_android_data
rem   pull_fgo.bat <outdir>             choose output folder
rem   pull_fgo.bat <outdir> <f1> <f2>   pull specific files
rem
rem Notes:
rem   - The phone must be unlocked and USB-debugging authorized (tap Allow on the
rem     RSA prompt the first time you plug in).
rem   - Requires adb.exe somewhere on PATH. If it's missing, this script offers
rem     to open Google's official Platform-Tools download page.
rem ---------------------------------------------------------------------------

set "ADB_URL=https://developer.android.com/tools/releases/platform-tools"

rem --- output dir + file list -------------------------------------------------

set "OUTDIR=%~1"
if "%OUTDIR%"=="" set "OUTDIR=fgo_android_data"

set "COUNT=0"
:collect_args
if "%~2"=="" goto args_done
set /a COUNT+=1
set "FILE!COUNT!=%~2"
shift
goto collect_args
:args_done

if "%COUNT%"=="0" (
  set "FILE1=54cc"
  set "FILE2=969b"
  set "FILE3=644b"
  set "FILE4=e1a9"
  set /a COUNT=4
)

rem --- ensure adb is available ------------------------------------------------

where adb >nul 2>&1
if errorlevel 1 (
  echo.
  echo   adb not found on PATH.
  echo.
  echo   Get the official Android SDK Platform-Tools here:
  echo     %ADB_URL%
  echo.
  echo   Download "SDK Platform-Tools for Windows", unzip it, and either add that
  echo   folder to PATH or drop adb.exe next to this script.
  echo.
  choice /c YN /m "Open the download page now" >nul 2>&1
  if not errorlevel 2 start "" "%ADB_URL%"
  echo.
  echo   Install adb first, then re-run.
  pause
  exit /b 1
)

rem --- wait for a device ------------------------------------------------------

set "STATE="
set /a tries=0
:wait_device
adb get-state >nul 2>&1
for /f "delims=" %%s in ('adb get-state 2^>nul') do set "STATE=%%s"
if "%STATE%"=="device" goto device_ready
if "%STATE%"=="unauthorized" echo   Waiting for USB-debugging authorization on the phone...
set /a tries+=1
if !tries! GEQ 30 goto no_device
ping -n 3 127.0.0.1 >nul
goto wait_device

:no_device
echo.
echo   error: no authorized device (state: %STATE%)
echo   Plug in the phone, unlock it, and accept the "Allow USB debugging?" prompt.
pause
exit /b 1

:device_ready
adb devices -l

rem --- pull -------------------------------------------------------------------

set "REMOTE_BASE=/sdcard/Android/data/com.aniplex.fategrandorder.en/files/data"

if not exist "%OUTDIR%\files\data\" mkdir "%OUTDIR%\files\data"

set /a OK=0
set /a FAIL=0
set /a i=1
:pull_loop
if !i! GTR %COUNT% goto pull_done
call set "f=%%FILE!i!%%"
adb pull "%REMOTE_BASE%/!f!" "%OUTDIR%\files\data" >nul 2>&1
if errorlevel 1 (
  echo   missing: !f!
  set /a FAIL+=1
) else (
  echo   ok: !f!
  set /a OK+=1
)
set /a i+=1
goto pull_loop

:pull_done
echo.
echo pulled !OK! file(s), !FAIL! missing -^> %OUTDIR%\files\data\
if "!FAIL!"=="0" (exit /b 0) else (exit /b 1)