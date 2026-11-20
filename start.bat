@echo off
rem Starts the ZEN Scene Builder and opens it in your browser.
start "" http://localhost:5173/
powershell -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 5173
