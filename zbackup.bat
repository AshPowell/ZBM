@echo off
REM Project Zomboid Backup and Restore Script

:MENU
cls
echo ====================================================
echo    Project Zomboid Backup and Restore Tool by ALP
echo ====================================================
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
set "backupBaseDir=%~dp0"

REM Get current timestamp
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "timestamp=%%a"

set "tempBackupDir=%backupBaseDir%PZ_Backup_Temp"
mkdir "%tempBackupDir%" >nul 2>&1

REM Define directories to back up
set "dirsToBackup=Server Saves\Multiplayer Multiplayer mods db Lua"

for %%D in (%dirsToBackup%) do (
    if exist "%UserProfile%\Zomboid\%%D" (
        echo Copying %%D...
        xcopy "%UserProfile%\Zomboid\%%D" "%tempBackupDir%\%%D" /E /I >nul
    ) else (
        echo Directory not found: %%D. Skipping...
    )
)

REM Detect Steam path
call :DetectSteamPath

if not "%SteamPath%"=="" (
    echo Copying Steam Workshop content...
    set "WorkshopContentPath=%SteamPath%\steamapps\workshop\content\108600"
    if exist "%WorkshopContentPath%" (
        xcopy "%WorkshopContentPath%" "%tempBackupDir%\Workshop\content\108600" /E /I >nul
    ) else (
        echo Steam Workshop content not found.
    )
)

echo Creating zip archive...
set "zipFileName=ProjectZomboidBackup_%timestamp%.zip"
powershell -NoProfile -Command "Compress-Archive -Path '%tempBackupDir%\*' -DestinationPath '%backupBaseDir%%zipFileName%' -Force"

rmdir /S /Q "%tempBackupDir%"
echo Backup completed: %backupBaseDir%%zipFileName%
pause
goto MENU

:RESTORE
echo.
echo Starting restore process...
echo.
echo Available backup files:
setlocal enabledelayedexpansion
set /a index=0

REM List zip files and create a selection menu
for /f "tokens=*" %%F in ('dir /b "%~dp0ProjectZomboidBackup_*.zip"') do (
    set /a index+=1
    set "file[!index!]=%%F"
    echo [!index!] %%F
)

if "!index!"=="0" (
    echo No backup files found.
    pause
    goto MENU
)

set /p fileChoice="Enter the number of the backup file to restore: "
set "zipFileName=!file[%fileChoice%]!"

if not defined zipFileName (
    echo Invalid selection. Please try again.
    pause
    goto RESTORE
)

set "zipFilePath=%~dp0%zipFileName%"
if not exist "%zipFilePath%" (
    echo File not found. Please ensure the file exists.
    pause
    goto MENU
)

echo WARNING: This will overwrite your current Project Zomboid data.
set /p confirm="Do you want to proceed? (Y/N): "
if /I "%confirm%" NEQ "Y" (
    echo Restore canceled.
    pause
    goto MENU
)

echo Extracting backup data...
powershell -NoProfile -Command "Expand-Archive -Path '%zipFilePath%' -DestinationPath '%~dp0PZ_Restore_Temp' -Force"

REM Restore process
set "tempRestoreDir=%~dp0PZ_Restore_Temp"
set "dirsToRestore=Server Saves\Multiplayer Multiplayer mods db Lua"

for %%D in (%dirsToRestore%) do (
    if exist "%tempRestoreDir%\%%D" (
        call :RestoreData "%tempRestoreDir%\%%D" "%UserProfile%\Zomboid\%%D"
    ) else (
        echo Directory not found in backup: %%D. Skipping...
    )
)

if exist "%tempRestoreDir%\Workshop\content\108600" (
    echo Restoring Steam Workshop content...
    call :RestoreData "%tempRestoreDir%\Workshop\content\108600" "%SteamPath%\steamapps\workshop\content\108600"
)

rmdir /S /Q "%tempRestoreDir%"
echo Restore completed successfully!
pause
goto MENU

:DetectSteamPath
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Wow6432Node\Valve\Steam" /v "InstallPath" 2^>nul') do (
    if /I "%%A"=="InstallPath" set "SteamPath=%%B"
)
if "%SteamPath%"=="" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Valve\Steam" /v "InstallPath" 2^>nul') do (
        if /I "%%A"=="InstallPath" set "SteamPath=%%B"
    )
)
set "SteamPath=%SteamPath:~1%"
goto :eof

:RestoreData
set "source=%~1"
set "destination=%~2"
if exist "%destination%" (
    echo Overwriting "%destination%"...
)
xcopy "%source%" "%destination%" /E /I /-Y >nul
goto :eof
