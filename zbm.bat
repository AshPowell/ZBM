@echo OFF
SETLOCAL enabledelayedexpansion enableextensions

title Project Zomboid Server Save Handler

REM USER SETUP
REM Name of the server (Check the .ini file in the Zomboid folder, e.g., servertest.ini)
set server_name=
REM Default location of the Zomboid folder (inside the user folder, NOT the Steam folder)
set def_zomboid_loc=%USERPROFILE%\Zomboid
REM Default location for zip files (Downloads folder)
set def_zip_loc=%USERPROFILE%\Downloads
REM URL to open (optional, include quotes if defined)
set url=
REM Backup option: 1 = true, 0 = false
set backup_option=1

:start
echo ...................................................................................
echo : Project Zomboid Server Save Handler                                           :
echo ...................................................................................
echo.
echo Visit the GitHub page for more information: https://github.com/pabloherresp/PZ-Server-Save-Manager
echo.

if NOT defined server_name (goto :noname)

:options
echo.
echo - OPTIONS -
echo 1. SAVE a new zip file
echo 2. LOAD from an existing zip file
echo 3. OPEN the zip folder
echo 4. FIX missing map files for a server
if "%url%" NEQ "" (echo 5. OPEN the URL link)
echo 0. CLOSE the program
set /p "id=Choose an option: "

if "%id%"=="1" (goto :save)
if "%id%"=="2" (goto :load)
if "%id%"=="3" (explorer "%def_zip_loc%" & goto :options)
if "%id%"=="4" (goto :fix_map)
if "%id%"=="5" (if "%url%" NEQ "" (explorer "%url%") else (echo ERROR: No URL has been defined.) & goto :options)
if "%id%"=="0" (goto :end)

echo ERROR: Invalid option. Please try again.
goto :options

:save
echo Creating zip file...
cd "%def_zomboid_loc%" || (echo ERROR: Zomboid folder not found & goto :options)

Call :get_date_time

tar -cf "%def_zip_loc%\!date_time!_PZ_server_%server_name%.zip" db\%server_name%.db
tar -uf "%def_zip_loc%\!date_time!_PZ_server_%server_name%.zip" Saves\Multiplayer\%server_name% Saves\Multiplayer\%server_name%_player
tar -uf "%def_zip_loc%\!date_time!_PZ_server_%server_name%.zip" Server\%server_name%.ini Server\%server_name%_SandboxVars.lua Server\%server_name%_spawnregions.lua

echo Zip file created: %def_zip_loc%\!date_time!_PZ_server_%server_name%.zip
goto :options

:load
echo Listing available zip files...
cd "%def_zip_loc%" || (echo ERROR: Zip folder not found & goto :options)

setlocal enabledelayedexpansion
set /A count=1
for %%x in ("*_PZ_server_%server_name%.zip") do (
    echo !count! - %%~nx
    set choice[!count!]=%%~nx
    set /A count+=1
)

if %count%==1 (
    echo No zip files found for server "%server_name%".
    goto :options
)

set /p "n=Choose a zip file by number: "
if "!choice[%n%]!"=="" (
    echo ERROR: Invalid choice.
    goto :load
)

if "%backup_option%"=="1" (
    echo Creating backup...
    Call :get_date_time
    set backup_dir=%def_zomboid_loc%\backups\!date_time!_backup
    mkdir "%backup_dir%" || (echo ERROR: Unable to create backup folder & goto :options)
    for %%d in (db Server Saves\Multiplayer) do (
        xcopy "%def_zomboid_loc%\%%d" "%backup_dir%\%%d" /E /H /C /I /Q
    )
    echo Backup completed: %backup_dir%
)

echo Extracting zip file: !choice[%n%]!
tar -xf "%def_zip_loc%\!choice[%n%]!" -C "%def_zomboid_loc%" || (echo ERROR: Extraction failed & goto :options)

echo Extraction completed.
goto :options

:fix_map
echo FIX MISSING MAP FILES
cd "%def_zomboid_loc%\Saves\Multiplayer" || (echo ERROR: Multiplayer saves folder not found & goto :options)

setlocal enabledelayedexpansion
set /A count=1
for /D %%x in (*) do (
    echo !count! - %%~nx
    set choice[!count!]=%%~nx
    set /A count+=1
)

set /p "n1=Choose the source folder: "
set /p "n2=Choose the target folder: "

if "%n1%"=="%n2%" (
    echo ERROR: Source and target folders cannot be the same.
    goto :fix_map
)

Call :get_date_time
set src=!choice[%n1%]!
set tgt=!choice[%n2%]!

ren "%tgt%\map_visited.bin" "map_visited_backup_!date_time!.bin"
ren "%tgt%\map_symbols.bin" "map_symbols_backup_!date_time!.bin"
xcopy "%src%\map_visited.bin" "%tgt%\" /Y /Q
xcopy "%src%\map_symbols.bin" "%tgt%\" /Y /Q

echo Map files fixed successfully.
goto :options

:noname
echo ERROR: You need to set the "server_name" variable at the beginning of this file.
echo Open this file with a text editor and set the value of "server_name".
set /p "f=Open the Zomboid folder now? (Y/N): "
if /I "%f%"=="Y" (explorer "%def_zomboid_loc%\Server")
goto :end

:end
echo Closing program.
pause
exit /b

:get_date_time
REM Formats date and time as YYYY_MM_DD__HH_MM_SS
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value') do set dt=%%i
set date_time=%dt:~0,4%_%dt:~4,2%_%dt:~6,2%__%dt:~8,2%_%dt:~10,2%_%dt:~12,2%
exit /b
