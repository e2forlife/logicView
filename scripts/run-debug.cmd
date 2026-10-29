@echo off
setlocal EnableExtensions
cd /d "%~dp0.."
rem Debug build: this console stays open for logs, and LogicView opens its window.
cargo run -p logicview-app -- %*
exit /b %ERRORLEVEL%
