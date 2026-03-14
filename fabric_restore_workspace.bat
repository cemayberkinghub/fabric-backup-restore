@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ==========================================
REM Simple Microsoft Fabric Workspace Restore
REM ==========================================


REM =========================
REM Backup / Restore Root
REM =========================

for /F %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"

set "CLR_RESET=%ESC%[0m"
set "CLR_YELLOW=%ESC%[33m"
set "CLR_GREEN=%ESC%[32m"
set "CLR_RED=%ESC%[31m"

set "DEFAULT_ROOT=%USERPROFILE%\pbi-backup"

set "ROOT="
set /p "ROOT=Enter backup root directory %CLR_YELLOW%(Press Enter for %DEFAULT_ROOT%)%CLR_RESET%: "

if "%ROOT%"=="" (
    set "ROOT=%DEFAULT_ROOT%"
)

if not exist "%ROOT%" mkdir "%ROOT%"

call :log "Using backup root: %ROOT%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
set "LOG_FILE=%ROOT%\fabric_restore_%TS%.log"

call :log "Restore root: %ROOT%"

where fab >nul 2>nul
if errorlevel 1 (
    echo Required command not found: fab
    exit /b 1
)

REM =========================
REM Login
REM =========================
call :log "Checking Fabric authentication..."
fab auth status >nul 2>nul
if errorlevel 1 (
    call :log "No active session found. Starting Fabric login..."
    fab auth login
    if errorlevel 1 (
        call :log_red "Authentication failed."
        exit /b 1
    )
)

call :log "Authentication check completed."

REM =========================
REM Inputs
REM =========================
set "NEW_WORKSPACE_NAME="
set "OLD_WORKSPACE_NAME="
set "CAPACITY_NAME="

set /p "NEW_WORKSPACE_NAME=Enter NEW Fabric workspace name %CLR_YELLOW%(Without .Workspace extension)%CLR_RESET% : " 
if not defined NEW_WORKSPACE_NAME (
    echo Workspace name cannot be empty.
    exit /b 1
)

set /p "OLD_WORKSPACE_NAME=Enter OLD workspace folder name %CLR_YELLOW%(backup source With .Workspace extension)%CLR_RESET% : "
if not defined OLD_WORKSPACE_NAME (
    echo Old workspace folder name cannot be empty.
    exit /b 1
)

set /p "CAPACITY_NAME=Enter Fabric capacity name: "
if not defined CAPACITY_NAME (
    echo Capacity name cannot be empty.
    exit /b 1
)

call :normalize_workspace_folder "%OLD_WORKSPACE_NAME%"
set "OLD_WORKSPACE_FOLDER=%RETVAL%"

set "OLD_WORKSPACE_DIR=%ROOT%\%OLD_WORKSPACE_FOLDER%"
set "NEW_WORKSPACE_PATH=%NEW_WORKSPACE_NAME%.Workspace"

call :log "New workspace name : %NEW_WORKSPACE_NAME%"
call :log "Old workspace root : %OLD_WORKSPACE_FOLDER%"
call :log "Backup source path : %OLD_WORKSPACE_DIR%"
call :log "Capacity name      : %CAPACITY_NAME%"

if not exist "%OLD_WORKSPACE_DIR%\" (
    call :log "Backup source folder not found: %OLD_WORKSPACE_DIR%"
    exit /b 1
)

REM =========================
REM Create workspace
REM =========================
call :log "Creating workspace: %NEW_WORKSPACE_PATH%"
fab mkdir "%NEW_WORKSPACE_PATH%" -P capacityName="%CAPACITY_NAME%"
if errorlevel 1 (
    call :log_red "Workspace creation failed."
    exit /b 1
)
call :log "Workspace created successfully."

REM =========================
REM Count item folders
REM =========================
set /a ITEM_COUNT=0
for /d %%D in ("%OLD_WORKSPACE_DIR%\*") do (
    set /a ITEM_COUNT+=1
)

if %ITEM_COUNT% EQU 0 (
    call :log_yellow "No item folders found under: %OLD_WORKSPACE_DIR%"
    exit /b 1
)

call :log_yellow "Found %ITEM_COUNT% item folder(s)."

REM =========================
REM Pass 1 - base artifacts
REM =========================
call :log "Starting pass 1: base artifacts"
for /d %%D in ("%OLD_WORKSPACE_DIR%\*") do (
    set "ITEM_FOLDER_NAME=%%~nxD"
    call :is_pass1 "!ITEM_FOLDER_NAME!"
    if "!RETVAL!"=="1" (
        call :import_item "%NEW_WORKSPACE_PATH%" "!ITEM_FOLDER_NAME!" "%%~fD"
    )
)

REM =========================
REM Pass 2 - reports
REM =========================
call :log "Starting pass 2: reports"
for /d %%D in ("%OLD_WORKSPACE_DIR%\*") do (
    set "ITEM_FOLDER_NAME=%%~nxD"
    call :is_pass2 "!ITEM_FOLDER_NAME!"
    if "!RETVAL!"=="1" (
        call :import_item "%NEW_WORKSPACE_PATH%" "!ITEM_FOLDER_NAME!" "%%~fD"
    )
)

REM =========================
REM Pass 3 - everything else
REM =========================
call :log "Starting pass 3: everything else"
for /d %%D in ("%OLD_WORKSPACE_DIR%\*") do (
    set "ITEM_FOLDER_NAME=%%~nxD"
    call :is_pass3 "!ITEM_FOLDER_NAME!"
    if "!RETVAL!"=="1" (
        call :import_item "%NEW_WORKSPACE_PATH%" "!ITEM_FOLDER_NAME!" "%%~fD"
    )
)

call :log "Restore completed."
echo.
echo Restore completed.
echo New Fabric workspace : %NEW_WORKSPACE_NAME%
echo Backup source folder : %OLD_WORKSPACE_DIR%
echo Log file             : %LOG_FILE%
goto :eof

REM =========================
REM Functions
REM =========================

:log
set "MSG=%~1"
echo [%date% %time%] %MSG%
>>"%LOG_FILE%" echo [%date% %time%] %MSG%
exit /b 0

:log_yellow
set "MSG=%~1"
echo %CLR_YELLOW%[%date% %time%] %MSG%%CLR_RESET%
>>"%LOG_FILE%" echo [%date% %time%] %MSG%
exit /b 0

:log_green
set "MSG=%~1"
echo %CLR_GREEN%[%date% %time%] %MSG%%CLR_RESET%
>>"%LOG_FILE%" echo [%date% %time%] %MSG%
exit /b 0

:log_red
set "MSG=%~1"
echo %CLR_RED%[%date% %time%] %MSG%%CLR_RESET%
>>"%LOG_FILE%" echo [%date% %time%] %MSG%
exit /b 0

:log_cyan
set "MSG=%~1"
echo %CLR_CYAN%[%date% %time%] %MSG%%CLR_RESET%
>>"%LOG_FILE%" echo [%date% %time%] %MSG%
exit /b 0

:normalize_workspace_folder
set "INPUT_NAME=%~1"
set "RETVAL=%INPUT_NAME%"
if /I not "%INPUT_NAME:~-10%"==".Workspace" set "RETVAL=%INPUT_NAME%.Workspace"
exit /b 0

:import_item
set "NEW_WS_PATH=%~1"
set "ITEM_NAME=%~2"
set "ITEM_SOURCE=%~3"
set "TARGET_PATH=%NEW_WS_PATH%/%ITEM_NAME%"

call :log "Importing: %ITEM_NAME%"
call :log "Source   : %ITEM_SOURCE%"
call :log "Target   : %TARGET_PATH%"

fab import "%TARGET_PATH%" -i "%ITEM_SOURCE%" --force
if errorlevel 1 (
    call :log_red "FAILED   : %ITEM_NAME%"
) else (
    call :log "OK       : %ITEM_NAME%"
)

exit /b 0

:is_pass1
set "NAME=%~1"
set "RETVAL=0"

echo %NAME% | findstr /R /I "\.SemanticModel$ \.Lakehouse$ \.Warehouse$ \.Notebook$ \.DataPipeline$ \.Environment$ \.Dataflow$ \.Eventhouse$ \.KQLDatabase$ \.KQLQueryset$" >nul
if not errorlevel 1 set "RETVAL=1"

exit /b 0

:is_pass2
set "NAME=%~1"
set "RETVAL=0"

echo %NAME% | findstr /R /I "\.Report$" >nul
if not errorlevel 1 set "RETVAL=1"

exit /b 0

:is_pass3
set "NAME=%~1"
set "RETVAL=1"

echo %NAME% | findstr /R /I "\.SemanticModel$ \.Lakehouse$ \.Warehouse$ \.Notebook$ \.DataPipeline$ \.Environment$ \.Dataflow$ \.Eventhouse$ \.KQLDatabase$ \.KQLQueryset$ \.Report$" >nul
if not errorlevel 1 set "RETVAL=0"

exit /b 0