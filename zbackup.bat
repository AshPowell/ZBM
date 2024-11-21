@echo off
REM Project Zomboid Backup and Restore Script

:MENU
cls
echo ==================================================
echo    Project Zomboid Backup and Restore Tool by ALP
echo ==================================================
echo.
echo Please select an option:
echo [1] Backup Project Zomboid Data
echo [2] Restore Project Zomboid Data
echo [3] Exit
echo.
set /p choice="Enter your choice [1-3]: "

if "%choice%"=="1" goto BACKUP
if "%choice%"=="2" goto RESTORE
if "%choice%"=="3" exit
goto MENU

:BACKUP
echo.
echo Starting backup process...
REM Set backup base directory to current directory
set "backupBaseDir=%~dp0"

REM Get current timestamp using PowerShell for consistency
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "timestamp=%%a"

set "tempBackupDir=%backupBaseDir%PZ_Backup_Temp"

REM Create temporary backup directory
mkdir "%tempBackupDir%" >nul 2>&1

REM Copy necessary data to temporary backup directory
echo Copying server settings...
xcopy "%UserProfile%\Zomboid\Server" "%tempBackupDir%\Server" /E /I >nul

echo Copying multiplayer save data...
xcopy "%UserProfile%\Zomboid\Saves\Multiplayer" "%tempBackupDir%\Saves\Multiplayer" /E /I >nul

echo Copying character data...
xcopy "%UserProfile%\Zomboid\Multiplayer" "%tempBackupDir%\Multiplayer" /E /I >nul

echo Copying mods...
xcopy "%UserProfile%\Zomboid\mods" "%tempBackupDir%\mods" /E /I >nul

REM Detect Steam installation path from registry
echo Detecting Steam installation path...
set "SteamPath="
REM Try to get Steam path from 64-bit registry
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Wow6432Node\Valve\Steam" /v "InstallPath" 2^>nul') do (
    if /I "%%A"=="InstallPath" set "SteamPath=%%B"
)
REM If not found, try 32-bit registry
if "%SteamPath%"=="" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Valve\Steam" /v "InstallPath" 2^>nul') do (
        if /I "%%A"=="InstallPath" set "SteamPath=%%B"
    )
)
REM Remove any leading spaces
set "SteamPath=%SteamPath:~1%"

if not "%SteamPath%"=="" (
    REM Copy Steam Workshop content for Project Zomboid (AppID 108600)
    echo Steam installation detected at "%SteamPath%"
    set "WorkshopContentPath=%SteamPath%\steamapps\workshop\content\108600"
    if exist "%WorkshopContentPath%" (
        echo Copying Steam Workshop content...
        xcopy "%WorkshopContentPath%" "%tempBackupDir%\Workshop\content\108600" /E /I >nul
    ) else (
        echo Steam Workshop content directory for Project Zomboid not found.
    )
) else (
    echo Steam installation not found. Skipping Steam Workshop content backup.
)

echo Creating zip archive...
set "zipFileName=ProjectZomboidBackup_%timestamp%.zip"
powershell -NoProfile -Command "Compress-Archive -Path '%tempBackupDir%\*' -DestinationPath '%backupBaseDir%%zipFileName%' -Force"

REM Clean up temporary backup directory
rmdir /S /Q "%tempBackupDir%"

echo.
echo Backup completed successfully!
echo Backup file created: %backupBaseDir%%zipFileName%
pause
goto MENU

:RESTORE
echo.
echo Starting restore process...
echo.
REM List available backup zip files
echo Available backup files:
dir /b "%~dp0ProjectZomboidBackup_*.zip"
echo.
set /p zipFileName="Enter the name of the backup zip file to restore (including .zip): "
if not exist "%~dp0%zipFileName%" (
    echo File not found. Please ensure the file exists in the current directory.
    pause
    goto MENU
)

echo.
echo WARNING: Restoring the backup will overwrite your current Project Zomboid data.
set /p confirm="Do you want to proceed? (Y/N): "
if /I "%confirm%" NEQ "Y" (
    echo Restore canceled.
    pause
    goto MENU
)

echo Extracting backup data...
powershell -NoProfile -Command "Expand-Archive -Path '%~dp0%zipFileName%' -DestinationPath '%~dp0PZ_Restore_Temp' -Force"

REM Restore data from temporary restore directory
set "tempRestoreDir=%~dp0PZ_Restore_Temp"

REM Check for existing data and prompt before overwriting
call :RestoreData "%tempRestoreDir%\Server" "%UserProfile%\Zomboid\Server"
call :RestoreData "%tempRestoreDir%\Saves\Multiplayer" "%UserProfile%\Zomboid\Saves\Multiplayer"
call :RestoreData "%tempRestoreDir%\Multiplayer" "%UserProfile%\Zomboid\Multiplayer"
call :RestoreData "%tempRestoreDir%\mods" "%UserProfile%\Zomboid\mods"

REM Restore Steam Workshop content
if exist "%tempRestoreDir%\Workshop\content\108600" (
    echo.
    echo Restoring Steam Workshop content...
    if not "%SteamPath%"=="" (
        call :RestoreData "%tempRestoreDir%\Workshop\content\108600" "%SteamPath%\steamapps\workshop\content\108600"
    ) else (
        echo Steam installation not found. Skipping Steam Workshop content restore.
    )
) else (
    echo No Steam Workshop content to restore.
)

REM Clean up temporary restore directory
rmdir /S /Q "%tempRestoreDir%"

echo.
echo Restore completed successfully!
pause
goto MENU

:RestoreData
REM Function to restore data with confirmation
set "source=%~1"
set "destination=%~2"

if not exist "%source%" (
    echo Source directory "%source%" does not exist. Skipping.
    goto :eof
)

if exist "%destination%" (
    echo.
    echo The destination "%destination%" already exists and will be overwritten.
    set /p overwrite="Do you want to overwrite it? (Y/N): "
    if /I "%overwrite%" NEQ "Y" (
        echo Skipping "%destination%".
        goto :eof
    )
)

echo Restoring "%destination%"...
xcopy "%source%" "%destination%" /E /I /-Y

goto :eof
