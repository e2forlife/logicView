@echo off
setlocal EnableExtensions
cd /d "%~dp0.."
cargo run -p logicview-app -- %*
exit /b %ERRORLEVEL%
