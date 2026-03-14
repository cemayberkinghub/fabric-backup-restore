@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Microsoft Fabric Workspace Restore Tool
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

REM ---- Resolve backup folder (argument or prompt) ----
if not "%~1"=="" (
    set "BACKUP_DIR=%~1"
) else (
    set /p "BACKUP_DIR=Enter the path to the backup folder: "
)

REM ---- Resolve target workspace name (argument or prompt) ----
if not "%~2"=="" (
    set "TARGET_WORKSPACE=%~2"
) else (
    set /p "TARGET_WORKSPACE=Enter the target workspace name (new or existing): "
)

REM Strip a trailing backslash if present
if "!BACKUP_DIR:~-1!"=="\" set "BACKUP_DIR=!BACKUP_DIR:~0,-1!"

echo.
echo Backup dir       : !BACKUP_DIR!
echo Target workspace : !TARGET_WORKSPACE!
echo.

REM ---- Validate backup directory ----
if not exist "!BACKUP_DIR!" (
    echo ERROR: Backup directory not found: !BACKUP_DIR!
    pause
    exit /b 1
)

REM ---- Locate the workspace items folder ----
REM fab export creates a "<WorkspaceName>.Workspace" subfolder inside the output dir.
REM If such a subfolder exists, restore from there; otherwise restore directly from
REM the backup dir (handles cases where the user points at the workspace subfolder).

set "ITEMS_DIR="
for /d %%D in ("!BACKUP_DIR!\*.Workspace") do (
    if "!ITEMS_DIR!"=="" set "ITEMS_DIR=%%D"
)
if "!ITEMS_DIR!"=="" set "ITEMS_DIR=!BACKUP_DIR!"

echo Items location: !ITEMS_DIR!
echo.

REM ---- Count item folders ----
set "ITEM_COUNT=0"
for /d %%D in ("!ITEMS_DIR!\*") do set /a ITEM_COUNT+=1

if %ITEM_COUNT%==0 (
    echo ERROR: No item folders found in "!ITEMS_DIR!".
    pause
    exit /b 1
)

echo Found %ITEM_COUNT% item(s) to restore.
echo.

REM ---- Restore each item ----
set "SUCCESS_COUNT=0"
set "FAIL_COUNT=0"

for /d %%D in ("!ITEMS_DIR!\*") do (
    set "ITEM_NAME=%%~nxD"
    echo Restoring: !ITEM_NAME!

    fab import "!TARGET_WORKSPACE!.Workspace/!ITEM_NAME!" -i "%%D" -f

    if !errorlevel! neq 0 (
        echo   [FAILED] !ITEM_NAME!
        set /a FAIL_COUNT+=1
    ) else (
        echo   [OK] !ITEM_NAME!
        set /a SUCCESS_COUNT+=1
    )
    echo.
)

echo.
echo ============================================
echo  Restore Summary
echo  Total:      %ITEM_COUNT%
echo  Successful: %SUCCESS_COUNT%
echo  Failed:     %FAIL_COUNT%
echo ============================================

if %FAIL_COUNT% gtr 0 (
    echo.
    echo WARNING: Some items failed to restore. Common causes:
    echo   - Item already exists in the target workspace
    echo   - Item type is not supported for import
    echo   - Missing connections or dependencies
    echo.
    echo Tip: Use a new, empty workspace as the restore target.
)

pause
exit /b 0
