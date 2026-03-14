@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =========================
REM Configuration
REM =========================
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
set "LOG_FILE=%ROOT%\fabric_backup_%TS%.log"
set "LS_JSON=%TEMP%\fab_ls_workspace_%TS%.json"
set "ITEMS_TXT=%TEMP%\fab_item_names_%TS%.txt"

REM =========================
REM Pre-flight
REM =========================
call :log "Backup root: %ROOT%"

where fab >nul 2>nul
if errorlevel 1 (
    echo Required command not found: fab
    exit /b 1
)

call :check_login
if errorlevel 1 exit /b 1

REM =========================
REM Input
REM =========================
set "WORKSPACE_NAME="
set /p "WORKSPACE_NAME=Enter Fabric workspace name to back up %CLR_YELLOW%(With .Workspace extension)%CLR_RESET%: "

if not defined WORKSPACE_NAME (
    echo Workspace name cannot be empty.
    exit /b 1
)

call :sanitize_name "%WORKSPACE_NAME%"
set "SAFE_WS_NAME=%RETVAL%"
set "WORKSPACE_DIR=%ROOT%\%SAFE_WS_NAME%"

if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"

call :log "Workspace : %WORKSPACE_NAME%"
call :log "Folder    : %WORKSPACE_DIR%"

REM =========================
REM List workspace items
REM =========================
fab ls "%WORKSPACE_NAME%" -l --output_format json > "%LS_JSON%" 2>>"%LOG_FILE%"
if errorlevel 1 (
    call :log_red "FAILED to list items in workspace: %WORKSPACE_NAME%"
    exit /b 1
)

powershell -NoProfile -Command ^
  "$j = Get-Content '%LS_JSON%' -Raw | ConvertFrom-Json; if ($j.status -ne 'Success') { exit 1 }"
if errorlevel 1 (
    call :log "Fabric CLI returned failure for workspace: %WORKSPACE_NAME%"
    type "%LS_JSON%"
    exit /b 1
)

REM Extract only valid item names like name.type into ASCII text file
powershell -NoProfile -Command ^
  "$j = Get-Content '%LS_JSON%' -Raw | ConvertFrom-Json; " ^
  "$names = @($j.result.data | ForEach-Object { $_.name } | " ^
  "Where-Object { $_ -is [string] -and $_.Trim() -ne '' -and $_ -match '\.[^\\.\\/]+$' }); " ^
  "$names | Out-File -FilePath '%ITEMS_TXT%' -Encoding ascii"

if errorlevel 1 (
    call :log_red "FAILED to extract item names from workspace JSON."
    exit /b 1
)

REM Count items before export
set "ITEM_COUNT=0"
for /f %%I in ('find /c /v "" ^< "%ITEMS_TXT%"') do set "ITEM_COUNT=%%I"

call :log_yellow "Items found: %ITEM_COUNT%"

if "%ITEM_COUNT%"=="0" (
    call :log "No items found in workspace."
    echo.
    echo Debug JSON output:
    type "%LS_JSON%"
    exit /b 1
)

REM =========================
REM Export items
REM =========================
for /f "usebackq delims=" %%N in ("%ITEMS_TXT%") do (
    if not "%%~N"=="" (
        call :export_item "%WORKSPACE_NAME%" "%WORKSPACE_DIR%" "%%~N"
    )
)

call :log "Backup completed."
echo.
echo Done. Workspace backup completed: %WORKSPACE_NAME%
echo Backup folder: %WORKSPACE_DIR%
echo Log file: %LOG_FILE%

del "%LS_JSON%" >nul 2>nul
del "%ITEMS_TXT%" >nul 2>nul
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
:check_login
call :log "Checking Fabric authentication..."

fab auth status >nul 2>nul
if errorlevel 1 (
    call :log "No active Fabric CLI session. Starting interactive login..."
    fab auth login
    if errorlevel 1 (
        call :log_red "Authentication failed."
        exit /b 1
    )
)

call :log "Already authenticated to Fabric CLI."
exit /b 0

:sanitize_name
setlocal
set "INPUT=%~1"

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$s = '%INPUT%';" ^
  "$s = $s -replace '[\\/:*?""<>|]', '_';" ^
  "$s = $s -replace '[\. ]+$', '';" ^
  "if ([string]::IsNullOrWhiteSpace($s)) { $s = '_unnamed_' };" ^
  "Write-Output $s"`) do (
    set "SANITIZED=%%A"
)

endlocal & set "RETVAL=%SANITIZED%"
exit /b 0

:export_item
set "WS_NAME=%~1"
set "WS_DIR=%~2"
set "ITEM_NAME=%~3"

call :sanitize_name "%ITEM_NAME%"
set "SAFE_ITEM_NAME=%RETVAL%"
set "FABRIC_ITEM_PATH=%WS_NAME%/%ITEM_NAME%"

call :log "Exporting: %FABRIC_ITEM_PATH% to %WS_DIR%\%SAFE_ITEM_NAME%"

REM Export to workspace root; Fabric creates the item folder under it
fab export "%FABRIC_ITEM_PATH%" -o "%WS_DIR%" -f --force
if errorlevel 1 (
    call :log_red "FAILED   : %FABRIC_ITEM_PATH%"
) else (
    call :log "OK       : %WS_DIR%\%SAFE_ITEM_NAME%"
)

exit /b 0