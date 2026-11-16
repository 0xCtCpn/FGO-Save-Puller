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
rem   - Requires adb.exe somewhere on PATH. If it's missing, this script can
rem     install the official SDK Platform-Tools automatically (asks first).
rem ---------------------------------------------------------------------------

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

set "ADB=adb"
where adb >nul 2>&1
if not errorlevel 1 goto adb_ready

if exist "%~dp0adb.exe" (
  set "ADB=%~dp0adb.exe"
  goto adb_ready
)
if exist "%~dp0platform-tools\adb.exe" (
  set "ADB=%~dp0platform-tools\adb.exe"
  goto adb_ready
)

echo.
echo   adb was not found on PATH or next to this script.
echo.
echo   This script can install the official Android SDK Platform-Tools
echo   automatically (~15 MB download from developer.android.com).
echo.
choice /c YN /n /m "  Install adb now? [Y/N] "
if errorlevel 2 (
  echo.
  echo   Cancelled. Install adb first, then re-run.
  pause
  exit /b 1
)

rem Download the official Windows Platform-Tools zip and unpack it next to the script.
set "ZIP_URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
set "ZIP=%TEMP%\fgo-platform-tools-%RANDOM%.zip"

echo.
echo   Downloading Android SDK Platform-Tools from Google...
echo     %ZIP_URL%
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%ZIP%' -UseBasicParsing } catch { Write-Host ('download failed: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
  echo.
  echo   error: download failed. Check your connection and try again.
  del "%ZIP%" >nul 2>&1
  pause
  exit /b 1
)

echo   Extracting...
powershell -NoProfile -Command "try { Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%~dp0' -Force } catch { Write-Host ('extract failed: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
  echo.
  echo   error: extraction failed.
  del "%ZIP%" >nul 2>&1
  pause
  exit /b 1
)
del "%ZIP%" >nul 2>&1

if not exist "%~dp0platform-tools\adb.exe" (
  echo.
  echo   error: adb.exe not found after extraction.
  pause
  exit /b 1
)
set "ADB=%~dp0platform-tools\adb.exe"

echo.
echo   adb installed -^> %ADB%
echo.

:adb_ready

rem sanity check that the resolved adb actually runs
"%ADB%" version >nul 2>&1
if errorlevel 1 (
  echo   error: adb is not usable: %ADB%
  pause
  exit /b 1
)

rem --- wait for a device ------------------------------------------------------

set "STATE="
set /a tries=0
:wait_device
for /f "usebackq delims=" %%s in (`"%ADB%" get-state 2^>nul`) do set "STATE=%%s"
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
"%ADB%" devices -l

rem --- pull -------------------------------------------------------------------

set "REMOTE_BASE=/sdcard/Android/data/com.aniplex.fategrandorder.en/files/data"

if not exist "%OUTDIR%\files\data\" mkdir "%OUTDIR%\files\data"

set /a OK=0
set /a FAIL=0
set /a i=1
:pull_loop
if !i! GTR %COUNT% goto pull_done
call set "f=%%FILE!i!%%"
"%ADB%" pull "%REMOTE_BASE%/!f!" "%OUTDIR%\files\data" >nul 2>&1
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