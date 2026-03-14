@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Microsoft Fabric Workspace Backup Tool
echo  Powered by FAB CLI (ms-fabric-cli)
echo ============================================
echo.

REM ---- Check that FAB CLI is installed ----
where fab >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: FAB CLI is not installed or not in PATH.
    echo        Install it with:  pip install ms-fabric-cli
    echo        Then log in with: fab auth login
    pause
    exit /b 1
)

REM ---- Resolve workspace name (argument or prompt) ----
if not "%~1"=="" (
    set "WORKSPACE_NAME=%~1"
) else (
    set /p "WORKSPACE_NAME=Enter the Fabric workspace name to back up: "
)

REM ---- Resolve backup base directory (argument or prompt) ----
if not "%~2"=="" (
    set "BACKUP_BASE_DIR=%~2"
) else (
    set /p "BACKUP_BASE_DIR=Enter backup directory (e.g. C:\FabricBackups): "
)

REM Strip a trailing backslash if present
if "!BACKUP_BASE_DIR:~-1!"=="\" set "BACKUP_BASE_DIR=!BACKUP_BASE_DIR:~0,-1!"

REM ---- Build a timestamped destination folder ----
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "_DT=%%I"
set "TIMESTAMP=!_DT:~0,4!-!_DT:~4,2!-!_DT:~6,2!_!_DT:~8,2!-!_DT:~10,2!-!_DT:~12,2!"
set "BACKUP_DIR=!BACKUP_BASE_DIR!\!WORKSPACE_NAME!_!TIMESTAMP!"

echo.
echo Workspace  : !WORKSPACE_NAME!
echo Backup dir : !BACKUP_DIR!
echo.

REM ---- Create the destination folder ----
if not exist "!BACKUP_DIR!" (
    mkdir "!BACKUP_DIR!"
    if %errorlevel% neq 0 (
        echo ERROR: Failed to create backup directory "!BACKUP_DIR!".
        pause
        exit /b 1
    )
)

REM ---- Export all workspace items ----
echo Exporting all items from workspace "!WORKSPACE_NAME!" ...
echo.
fab export "!WORKSPACE_NAME!.Workspace" -o "!BACKUP_DIR!" -a -f

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Backup failed.
    echo   - Verify the workspace name is correct.
    echo   - Make sure you are authenticated: fab auth login
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Backup completed successfully!
echo  Workspace items saved to:
echo  !BACKUP_DIR!
echo ============================================
pause
exit /b 0
