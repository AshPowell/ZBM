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

REM Set backup base directory to current directory
set "backupBaseDir=%~dp0"

REM Clean up temporary backup directory if it exists
set "tempBackupDir=%backupBaseDir%PZ_Backup_Temp"
if exist "%tempBackupDir%" (
    echo Cleaning up previous temporary backup...
    rmdir /S /Q "%tempBackupDir%" >nul 2>&1
)

REM Get current timestamp using PowerShell for consistency
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "timestamp=%%a"

mkdir "%tempBackupDir%" >nul 2>&1

REM Define an array of directories to backup
set "dirsToBackup=Server Saves\Multiplayer Multiplayer mods db Lua"

REM Loop through directories and copy if they exist
for %%D in (%dirsToBackup%) do (
    if exist "%UserProfile%\Zomboid\%%D" (
        echo Copying %%D...
        xcopy "%UserProfile%\Zomboid\%%D" "%tempBackupDir%\%%D" /E /I /Q >nul
    ) else (
        echo Directory not found: %%D. Skipping...
    )
)

REM Detect Steam installation path from registry
echo Detecting Steam installation path...
call :DetectSteamPath

if not "%SteamPath%"=="" (
    echo Steam installation detected at "%SteamPath%"
    REM Copy Steam Workshop content for Project Zomboid (AppID 108600)
    set "WorkshopContentPath=%SteamPath%\steamapps\workshop\content\108600"
    if exist "%WorkshopContentPath%" (
        echo Copying Steam Workshop content...
        xcopy "%WorkshopContentPath%" "%tempBackupDir%\Workshop\content\108600" /E /I /Q >nul
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
rmdir /S /Q "%tempBackupDir%" >nul 2>&1

echo.
echo Backup completed successfully!
echo Backup file created: %backupBaseDir%%zipFileName%
pause
goto MENU

:RESTORE
echo.
echo Starting restore process...
echo.

REM List available backup zip files and allow user to select by number
setlocal enabledelayedexpansion
set /a index=0

echo Available backup files:
for /f "delims=" %%F in ('dir /b /o-d "%~dp0ProjectZomboidBackup_*.zip"') do (
    set /a index+=1
    set "file[!index!]=%%F"
    echo [!index!] %%F
)
if "%index%"=="0" (
    echo No backup files found.
    pause
    endlocal
    goto MENU
)

echo.
set /p fileChoice="Enter the number of the backup file to restore: "
set "zipFileName=!file[%fileChoice%]!"

if not defined zipFileName (
    echo Invalid selection. Please try again.
    pause
    endlocal
    goto RESTORE
)

set "zipFilePath=%~dp0%zipFileName%"

if not exist "%zipFilePath%" (
    echo File not found. Please ensure the file exists.
    pause
    endlocal
    goto MENU
)

endlocal

echo.
echo WARNING: Restoring the backup will overwrite your current Project Zomboid data.
set /p confirm="Do you want to proceed? (Y/N): "
if /I "%confirm%" NEQ "Y" (
    echo Restore canceled.
    pause
    goto MENU
)

echo Extracting backup data...
set "tempRestoreDir=%~dp0PZ_Restore_Temp"
REM Clean up temporary restore directory if it exists
if exist "%tempRestoreDir%" (
    echo Cleaning up previous temporary restore data...
    rmdir /S /Q "%tempRestoreDir%" >nul 2>&1
)

powershell -NoProfile -Command "Expand-Archive -Path '%zipFilePath%' -DestinationPath '%tempRestoreDir%' -Force"

REM Restore data from temporary restore directory
REM Define an array of directories to restore
set "dirsToRestore=Server Saves\Multiplayer Multiplayer mods db Lua"

REM Loop through directories and restore with confirmation
for %%D in (%dirsToRestore%) do (
    if exist "%tempRestoreDir%\%%D" (
        call :RestoreData "%tempRestoreDir%\%%D" "%UserProfile%\Zomboid\%%D"
    ) else (
        echo Directory not found in backup: %%D. Skipping...
    )
)

REM Restore Steam Workshop content
if exist "%tempRestoreDir%\Workshop\content\108600" (
    echo.
    echo Restoring Steam Workshop content...
    call :DetectSteamPath
    if not "%SteamPath%"=="" (
        call :RestoreData "%tempRestoreDir%\Workshop\content\108600" "%SteamPath%\steamapps\workshop\content\108600"
    ) else (
        echo Steam installation not found. Skipping Steam Workshop content restore.
    )
) else (
    echo No Steam Workshop content to restore.
)

REM Clean up temporary restore directory
rmdir /S /Q "%tempRestoreDir%" >nul 2>&1

echo.
echo Restore completed successfully!
pause
goto MENU

:DetectSteamPath
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
goto :eof

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
) else (
    echo Creating "%destination%"...
    mkdir "%destination%" >nul 2>&1
)

echo Restoring "%destination%"...
xcopy "%source%" "%destination%" /E /I /-Y /Q

goto :eof