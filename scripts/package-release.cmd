@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

echo Building logicview release...
cargo build --release -p logicview-app
if errorlevel 1 (
  echo cargo build --release -p logicview-app failed.
  exit /b 1
)

if not exist "target\release\logicview.exe" (
  echo Missing target\release\logicview.exe
  exit /b 1
)

set "VERSION="
for /f "tokens=2 delims=#" %%V in ('cargo pkgid -p logicview-app') do (
  set "VERSION=%%V"
  goto :version_done
)
:version_done
if not defined VERSION (
  echo Could not read the logicview-app version from cargo pkgid.
  exit /b 1
)

set "STAGE=dist\logicview-%VERSION%"
set "ZIP=dist\logicview-%VERSION%-windows.zip"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
if exist "%ZIP%" del /f /q "%ZIP%"
mkdir "%STAGE%\assets"
if errorlevel 1 exit /b 1

copy /y "target\release\logicview.exe" "%STAGE%\logicview.exe" >nul
if errorlevel 1 exit /b 1

rem The packaged exe is a Windows GUI binary (subsystem 2). A console
rem subsystem would flash a terminal when the user launches LogicView.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%STAGE%\logicview.exe'; $b=[IO.File]::ReadAllBytes((Resolve-Path $p)); $pe=[BitConverter]::ToInt32($b,60); $sub=[BitConverter]::ToUInt16($b,$pe+92); if ($sub -ne 2) { Write-Error ('logicview.exe subsystem is ' + $sub + '; expected 2 (Windows GUI)'); exit 1 }"
if errorlevel 1 (
  echo logicview.exe is not a windowed Windows binary.
  exit /b 1
)

if not exist "crates\logicview-ui\assets\index.html" (
  echo Missing UI assets in crates\logicview-ui\assets
  exit /b 1
)
xcopy "crates\logicview-ui\assets" "%STAGE%\assets\" /E /I /Y /Q >nul
if errorlevel 1 (
  echo Failed to copy UI assets.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%STAGE%' -DestinationPath '%ZIP%' -Force"
if errorlevel 1 (
  echo Failed to write %ZIP%
  exit /b 1
)

echo Release package: %CD%\%ZIP%
exit /b 0
