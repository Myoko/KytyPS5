@echo off
rem The settings window (launcher.ps1): game folder, resolution, fullscreen, console language, precompile.
rem (Windows PowerShell by its path: with its folder missing from PATH, "powershell" was unknown, issue #55.)
rem Arguments are passed on, and a run with one keeps its console so its output (-DryRun) is visible.
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if "%~1"=="" (
	start "" "%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launcher.ps1"
) else (
	"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1" %*
)