@echo off
cls
echo.
echo   +===============================================================+
echo   ^|   )\\\ ARC RAIDERS - SKIP VIDEOS MOD                          ^|
echo   +===============================================================+
echo.
echo   Press any key to start...
pause >nul

rem ============================================================================
rem  Arc Raiders - Skip Videos Mod
rem ============================================================================
rem  Author:      TinyStormCloud
rem  Version:     1.15.0
rem  Description: Removes intro, match, and quest video files from Arc Raiders
rem               to skip cutscenes. Place this file in the Arc Raiders
rem               installation directory and run.
rem  Usage:       Double-click to run, or execute from command line
rem  Repository:  https://next.nexusmods.com/profile/TinyStormCloud/mods
rem ============================================================================

title Arc Raiders - Skip Videos Mod by TinyStormCloud

setlocal enabledelayedexpansion
set "WARN=[!]"

set "NEED_ADMIN=0"
set "ESC="
set "MOVIES_PATH="
set "CURRENT_DIR="
set "PF86=%ProgramFiles(x86)%"

rem --- 1. Try Steam registry (HKCU then HKLM) ---
set "_STEAM="
for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v "SteamPath" 2^>nul') do set "_STEAM=%%B"
if not defined _STEAM (
    for /f "tokens=2*" %%A in ('reg query "HKLM\Software\Wow6432Node\Valve\Steam" /v "InstallPath" 2^>nul') do set "_STEAM=%%B"
)
if defined _STEAM (
    set "_STEAM=!_STEAM:/=\!"
    if exist "!_STEAM!\steamapps\common\Arc Raiders\PioneerGame" (
        set "CURRENT_DIR=!_STEAM!\steamapps\common\Arc Raiders"
    )
)

rem --- 2. Try default Steam path via env var ---
if not defined CURRENT_DIR (
    if exist "!PF86!\Steam\steamapps\common\Arc Raiders\PioneerGame" (
        set "CURRENT_DIR=!PF86!\Steam\steamapps\common\Arc Raiders"
    )
)

rem --- 3. Try Epic Games default path ---
if not defined CURRENT_DIR (
    if exist "%ProgramFiles%\Epic Games\Arc Raiders\PioneerGame" (
        set "CURRENT_DIR=%ProgramFiles%\Epic Games\Arc Raiders"
    )
)

rem --- 4. Fall back to script directory (original behaviour) ---
if not defined CURRENT_DIR (
    set "CURRENT_DIR=%~dp0"
    set "CURRENT_DIR=!CURRENT_DIR:~0,-1!"
    if not exist "!CURRENT_DIR!\PioneerGame" (
        cls
        echo.
        echo       [X] ARC RAIDERS NOT FOUND
        echo.
        echo       Could not locate Arc Raiders automatically.
        echo       Place this file in the Arc Raiders installation directory and run again.
        echo.
        echo       Searched:
        echo       - Steam registry
        echo       - !PF86!\Steam\steamapps\common\Arc Raiders
        echo       - %ProgramFiles%\Epic Games\Arc Raiders
        echo.
        echo   +===============================================================+
        echo.
        echo   Press any key to exit...
        pause >nul
        endlocal
        exit /b 1
    )
)

if /i "%CURRENT_DIR:~0,2%"=="C:" set "NEED_ADMIN=1"

for /F %%e in ('echo prompt $E^| cmd') do set "ESC=%%e"
set "MOVIES_PATH=%CURRENT_DIR%\PioneerGame\Content\Movies"

:MENU
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[96m)%ESC%[92m\%ESC%[93m\%ESC%[91m\%ESC%[0m ARC RAIDERS - SKIP VIDEOS MOD by TinyStormCloud        ^|
echo   +===============================================================+
echo   ^|                                                               ^|
echo   ^|   1. Skip Intro Video                                         ^|
echo   ^|   2. Skip Match Video                                         ^|
echo   ^|   3. Skip Quest Videos                                        ^|
echo   ^|   4. Apply all                                                ^|
echo   ^|                                                               ^|
echo   ^|   5. Troubleshoot                                             ^|
echo   ^|   6. Credit                                                   ^|
echo   ^|                                                               ^|
echo   ^|   0. Exit                                                     ^|
echo   ^|                                                               ^|
echo   +===============================================================+
echo   ^|                                                      v1.15.0  ^|
echo   +===============================================================+
echo.
set "CHOICE="
set /p "CHOICE=   Select an option: "
if not "!CHOICE:~1,1!"=="" goto INVALID_MENU
if "!CHOICE!"=="1" goto SKIP_INTRO
if "!CHOICE!"=="2" goto SKIP_MATCH
if "!CHOICE!"=="3" goto SKIP_QUEST
if "!CHOICE!"=="4" goto APPLY_ALL
if "!CHOICE!"=="5" goto TROUBLESHOOT
if "!CHOICE!"=="6" goto CREDIT
if "!CHOICE!"=="0" goto EXIT
:INVALID_MENU
echo.
echo   %ESC%[91m[X]%ESC%[0m Invalid option. Please try again.
timeout /t 2 >nul
goto MENU

:SKIP_INTRO
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[96m)%ESC%[92m\%ESC%[93m\%ESC%[91m\%ESC%[0m APPLYING SKIP INTRO VIDEO MOD                          ^|
echo   +===============================================================+
echo.
call :DEL_FILE "%MOVIES_PATH%\FTUE" "GAME_INTRO_SPERANZA_DESCEND_V5.bk2"
echo.
echo   +===============================================================+
echo.
echo   Press any key to go back to menu...
pause >nul
goto MENU

:SKIP_MATCH
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[96m)%ESC%[92m\%ESC%[93m\%ESC%[91m\%ESC%[0m APPLYING SKIP MATCH VIDEO MOD                          ^|
echo   +===============================================================+
echo.
call :DEL_FILE "%MOVIES_PATH%\Frontend" "LaunchSequence_ToBlack_4k.bk2"
echo.
echo   +===============================================================+
echo.
echo   Press any key to go back to menu...
pause >nul
goto MENU

:SKIP_QUEST
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[93m!WARN!%ESC%[0m WARNING                                                 ^|
echo   +===============================================================+
echo.
echo       This mod is intended for players who have finished their
echo       first playthrough and have done the expedition, and
echo       don't want to rewatch quest videos.
echo.
echo   +===============================================================+
echo.
:QUEST_CONFIRM_LOOP
set "CONFIRM=_"
set /p "CONFIRM=   Do you want to continue? (Y/N): "
if not "!CONFIRM:~1,1!"=="" goto INVALID_QUEST
if /i "!CONFIRM!"=="Y" goto QUEST_APPLY
if /i "!CONFIRM!"=="N" goto MENU
:INVALID_QUEST
echo.
echo   %ESC%[91m[X]%ESC%[0m Invalid input. Please enter Y or N.
timeout /t 2 >nul
goto SKIP_QUEST

:QUEST_APPLY
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[96m)%ESC%[92m\%ESC%[93m\%ESC%[91m\%ESC%[0m APPLYING SKIP QUEST VIDEOS MOD                         ^|
echo   +===============================================================+
echo.
call :DEL_QUEST_FILES
echo.
echo   +===============================================================+
echo.
echo   Press any key to go back to menu...
pause >nul
goto MENU

:APPLY_ALL
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[93m!WARN!%ESC%[0m WARNING                                                 ^|
echo   +===============================================================+
echo.
echo       This will apply all mods. Skip Quest Videos is intended
echo       for players who have finished their first playthrough and
echo       have done their expedition, and don't want to rewatch
echo       story videos.
echo.
echo   +===============================================================+
echo.
:ALL_CONFIRM
set "CONFIRM=_"
set /p "CONFIRM=   Do you want to continue? (Y/N): "
if not "!CONFIRM:~1,1!"=="" goto INVALID_ALL
if /i "!CONFIRM!"=="Y" goto ALL_APPLY
if /i "!CONFIRM!"=="N" goto MENU
:INVALID_ALL
echo.
echo   %ESC%[91m[X]%ESC%[0m Invalid input. Please enter Y or N.
timeout /t 2 >nul
goto APPLY_ALL

:ALL_APPLY
cls
echo.
echo   +===============================================================+
echo   ^|   %ESC%[96m)%ESC%[92m\%ESC%[93m\%ESC%[91m\%ESC%[0m APPLYING ALL MODS                                      ^|
echo   +===============================================================+
echo.
call :DEL_FILE "%MOVIES_PATH%\FTUE"     "GAME_INTRO_SPERANZA_DESCEND_V5.bk2" "Skip Intro Video"
call :DEL_FILE "%MOVIES_PATH%\Frontend" "LaunchSequence_ToBlack_4k.bk2"      "Skip Match Video"
call :DEL_QUEST_FILES
echo.
echo   +===============================================================+
echo.
echo   Press any key to go back to menu...
pause >nul
goto MENU

rem ============================================================================
rem  Subroutine: DEL_FILE <dir> <filename> [label]
rem  Deletes a single video file. Optional label prefixes status messages.
rem ============================================================================
:DEL_FILE
set "_DIR=%~1"
set "_FILE=%_DIR%\%~2"
set "_LBL=%~3"
if not "%_LBL%"=="" set "_LBL=%_LBL% - "
if not exist "%_DIR%" (
    echo   %ESC%[91m[X]%ESC%[0m %_LBL%Directory not found
    if "%~3"=="" (
        echo.
        echo       Make sure this file is placed in the Arc Raiders
        echo       installation directory, or verify your game installation.
        echo.
        echo   +===============================================================+
        echo.
        echo   Press any key to go back to menu...
        pause >nul
        goto MENU
    )
    goto :EOF
)
if not exist "%_FILE%" (
    echo   %ESC%[93m!WARN!%ESC%[0m %_LBL%Already applied
    goto :EOF
)
del /f /q "%_FILE%" 2>nul
if not exist "%_FILE%" (
    echo   %ESC%[92m[v]%ESC%[0m %_LBL%Successfully applied
) else (
    echo   %ESC%[91m[X]%ESC%[0m %_LBL%Failed to delete file
    if "!NEED_ADMIN!"=="1" (
        echo       The file may be in use. Close the game and try again,
        echo       or run as Administrator.
    ) else (
        echo       The file may be in use. Close the game and try again.
    )
)
goto :EOF

rem ============================================================================
rem  Subroutine: DEL_QUEST_FILES
rem  Deletes all 11 quest video files.
rem ============================================================================
:DEL_QUEST_FILES
set "_QDIR=%MOVIES_PATH%\Quests"
if not exist "%_QDIR%" (
    echo   %ESC%[91m[X]%ESC%[0m Skip Quest Videos - Directory not found
    goto :EOF
)
echo   %ESC%[92m[v]%ESC%[0m Found directory
set "FILES_FOUND=0"
set "FILE1=%_QDIR%\Quest_Intro_A_Bad_Feeling.bk2"
set "FILE2=%_QDIR%\QUEST_INTRO_Dormant_Barons.bk2"
set "FILE3=%_QDIR%\QUEST_INTRO_Finders_Keepers.bk2"
set "FILE4=%_QDIR%\Quest_Intro_Finders_Keepers_V1.bk2"
set "FILE5=%_QDIR%\QUEST_INTRO_The_Root_of_the_matter.bk2"
set "FILE6=%_QDIR%\QUEST_OUTRO_A bad feeling.bk2"
set "FILE7=%_QDIR%\QUEST_OUTRO_Communication_Hideout.bk2"
set "FILE8=%_QDIR%\QUEST_OUTRO_Echoes_of_Victory_Ridge.bk2"
set "FILE9=%_QDIR%\QUEST_OUTRO_Into_the_Fray.bk2"
set "FILE10=%_QDIR%\QUEST_OUTRO_Switching_the_Supply.bk2"
set "FILE11=%_QDIR%\QUEST_OUTRO_SymbolOfUnification.bk2"
for %%F in ("%FILE1%" "%FILE2%" "%FILE3%" "%FILE4%" "%FILE5%" "%FILE6%" "%FILE7%" "%FILE8%" "%FILE9%" "%FILE10%" "%FILE11%") do (
    if exist %%F set /a FILES_FOUND+=1
)
if %FILES_FOUND%==0 (
    echo   %ESC%[93m!WARN!%ESC%[0m Skip Quest Videos - Already applied
    goto :EOF
)
echo   %ESC%[92m[v]%ESC%[0m Found !FILES_FOUND! of 11 files
set "FILES_DELETED=0"
for %%F in ("%FILE1%" "%FILE2%" "%FILE3%" "%FILE4%" "%FILE5%" "%FILE6%" "%FILE7%" "%FILE8%" "%FILE9%" "%FILE10%" "%FILE11%") do (
    if exist %%F (
        del /f /q %%F 2>nul
        if not exist %%F set /a FILES_DELETED+=1
    )
)
if %FILES_DELETED%==%FILES_FOUND% (
    echo   %ESC%[92m[v]%ESC%[0m Skip Quest Videos - Successfully applied
) else (
    echo   %ESC%[91m[X]%ESC%[0m Skip Quest Videos - Failed to delete files
    if "!NEED_ADMIN!"=="1" (
        echo       The files may be in use. Close the game and try again,
        echo       or run as Administrator.
    ) else (
        echo       The files may be in use. Close the game and try again.
    )
)
goto :EOF

:TROUBLESHOOT
cls
echo.
echo   +===============================================================+
echo   ^|   DIAGNOSTICS                                                 ^|
echo   +===============================================================+
echo.
if exist "%CURRENT_DIR%\PioneerGame" (
    echo       %ESC%[92m[v]%ESC%[0m Arc Raiders directory: %CURRENT_DIR%
) else (
    echo       %ESC%[91m[X]%ESC%[0m Arc Raiders directory not found
)
if /i "%CURRENT_DIR:~0,2%"=="C:" (
    echo       %ESC%[93m!WARN!%ESC%[0m Install directory is on C:\ drive
) else (
    echo       %ESC%[92m[v]%ESC%[0m Install directory is not on C:\ drive
)
if exist "%MOVIES_PATH%" (
    echo       %ESC%[92m[v]%ESC%[0m Found PioneerGame\Content\Movies
) else (
    echo       %ESC%[91m[X]%ESC%[0m Missing PioneerGame\Content\Movies
)
for %%D in (FTUE Frontend Quests) do (
    if exist "%MOVIES_PATH%\%%D" (
        echo       %ESC%[92m[v]%ESC%[0m Found Movies\%%D
    ) else (
        echo       %ESC%[91m[X]%ESC%[0m Missing Movies\%%D
    )
)
if exist "%MOVIES_PATH%" (
    set "_TMP=%MOVIES_PATH%\_write_test.tmp"
    echo test > "!_TMP!" 2>nul
    if exist "!_TMP!" (
        del /f /q "!_TMP!" 2>nul
        echo       %ESC%[92m[v]%ESC%[0m Write permissions OK
    ) else (
        echo       %ESC%[91m[X]%ESC%[0m No write permissions - run as Administrator
    )
) else (
    echo       %ESC%[91m[X]%ESC%[0m Cannot check write permissions - path missing
)
net session >nul 2>&1
if !errorlevel! == 0 (
    echo       %ESC%[92m[v]%ESC%[0m Running as Administrator
) else (
    echo       %ESC%[93m!WARN!%ESC%[0m Not running as Administrator
)
echo.
echo   +===============================================================+
echo   ^|   TROUBLESHOOT                                                ^|
echo   +===============================================================+
echo   ^|                                                               ^|
echo   ^|   1. Place this file in correct install directory:            ^|
echo   ^|      Steam: \steamapps\common\Arc Raiders                     ^|
echo   ^|      Epic:  \Epic Games\Arc Raiders                           ^|
echo   ^|                                                               ^|
echo   ^|   2. If issues persist, try running this                      ^|
echo   ^|      file as Administrator.                                   ^|
echo   ^|                                                               ^|
echo   ^|   3. Make sure Arc Raiders is version 1.15.0 or later.        ^|
echo   ^|                                                               ^|
echo   ^|   4. Restart PC after applying mod.                           ^|
echo   ^|                                                               ^|
echo   +===============================================================+
echo.
echo   Press any key to go back to menu...
pause >nul
goto MENU

:CREDIT
cls
echo                          @@@@@@@@@@@@@%%^&%%^&@@@@@@@^&@^&%%^&#*
echo                       @@^&@@@@@@@@@@^&@^&^&^&^&#@@@@@@@@%%^&^&#%%@^&%%
echo                     ^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@^&^&@^&^&^&^&^&^&
echo                    @@@^&@@@@@@@@@@@@@@@@^&@@@@@@@@@@@@@%%@^&@^&@^&^&
echo                   @@#%%@@@@@@@@@@@^&^&^&^&%%@%%@@@@@@@@@@@^&^&%%^&@@%%@%%^&/
echo                  *^&@@^&@@@@@@@@@@@@^&^&^&@@@@@@@@@@@@@@^&@^&@^&%%^&#@@#@^&,
echo                 .%%^&@^&@@@@@@@@@@@@@@^&^&@@^&@@@@^&@^&@@@@@%%%%^&#@#^&@@#*
echo                ./#@^&@@@@^&@@@@@^&@^&@@@@^&^&%%%%^&^&^&^&^&^&%%@^&@^&^&^&@%%#@^&^&^(^&##
echo                %%@@%%@%%^&^&@@@@@@@@@@@@#@^&#%%^&^&^&^&#@@#@#^&^&^&@%%%%#%%@@^&^&#*
echo               /#@#@^&^&%%@^&@@@@@@@@@@@@%%%%#^(%%@^&%%^&@^&@%%%%^&#^&^&#@%%^&^&@^&@@%%*^(
echo               ^(%%/%%#@^&#@@@@@@@@@@@@@@^&^&^(^(^(^(^&%%%%@^&#@#^&^&@@%%%%@@%%#^&^(/*
echo              ,%%/#^(^(@^&^&@@@@@@@@@@@@@@^&^(^(///^(^(#%%%%@@@@@%%%%@@%%^&@@^&%%^&%%.
echo               *^&@^&%%^(%%@@@@@@@@@@@@@###^(/////%%(%%@^&@@@@@@@@%%^(#/@@@%%/*
echo                ^(%%@%%%%#@###/^(@@@@@@@@^&@@%%^(**/#@^&@@@@@@^&#%%^(*,^(^&@,%%.
echo                 ,@^&^(@#,^&@^&@@@##@^&/%%%%^&^&%%/,.*^(^(%%#/#^(//^&*,**,.#,*%%,.
echo                  /@@@@,,^&^&#%%%%^&^&^&%%#^(^(#%%#*... ..,/^(**. ....   ^(@@*
echo                  ^&@@@@%% *%%#^(^(*^(///#%%%%^(,      . . ......  ^&@@@@^(
echo                 ^(@@@@@@..*^&%%#^(^(^(/**^(%%%%/.      ... ....   .@@@@/.
echo                 @@@@@@^&*//^(#%%#^(//*/%%%%%%%%%/*,..  ....      @@@@^&@^(
echo                 %%@@@@@@ *#%%%%%%%%%##/////##...              /@@@@@##
echo                %%@@@@@@   ,^&^&^&%%%%#^(^(^(##^&^&*%%^&.  .        * @@@@@@@
echo                ^&@@@@@@*    ^&^&^&^&%%%%##%%^&%%#^(%%/*/*.,*,.. ..   @@@@@@,
echo                %%@@@@@@,      ^&%%^&%%%%%%@%%#%%^(*,,,,,..,    *@@@@@^&%%
echo                @@@@@@@      //@^(/%%%%^(*,,..........    . ^(@@@@@^&@
echo                ^&^&@@@@@    //^&^&^&^&^&^&,%%#^(/*///*,....  ..,^& * @@^&^&@@#
echo               ^&@@@@@@    /.*##^&^&^&%%%%^&%%^&^&%%^(/*,.. .,.,     /@@@@@@@/
echo               ^&@@@@@@  .^(../%%^(##^(@##^(^(^(^(/**,....,       ,,,@^&@@@%%^(
echo               %%@@@@@#*@@.,*//##^(^(**,./,,,,,,,/           .*@@@@@^&,
echo               ^&@@@@@@@@@**//^(*,,......  .                #@@@@@@%%^&
echo             #@@@@@@@@@@@,,*,,,.  ..   @@^(^&/               @@%%@@@%%@/^&%%#
echo @@@@@@@*%%*@@^(%%@@^&@@@@@^&.,,,,....    ^&^&^&@@@@,            *@%%#@@@^(@@^&#%%%%^&#@^&@^&#^&@
echo @@@@@@@@@@%%@@@@@@/@@#@@@@,*,... .   ^&@^&@@^&^&@@/           @@#@@@@@@@@@^&##@@@^&@@@
echo @@@@@@@@@@@@@@^&@%%@@@@@*^&@*,,,...   ^(@@@@^&@%%*@@         @@@/%%#@@/,@@@^&^&^&,^&@^&@@@@
echo @^&@*@@@*@@@@@%%^&@@#^&@@@@@@@,,. .   @@@@@@@%%^&^&@@@@^(      *@@@@^&^(@@%%@@@#/@%%^&^&^&^&@@@
echo @^&@@@@@@@^&#@@^(@@%%^&@@@*^(^&@@@.,.  .^&@^&@@@*@@^&^&@@@@@@     ^&^&@@@#@@@@.,@@%%%%^&@^&%%#@@@
echo ^&@@@@@@@@@@@@^(@@*^&@@@@@^&^&@@... .%%@@@@@@@#@^&^&^&@@@^&@@^&  ,^&^&@@@^&/@@@@@^&#%%^&%%@@^&#@@@
echo @@@@@@@@@#@@^&/@^&^&@@@@#^(^&^&@^&@. ^&^&^&^&^&@@#.@.@^&^&@@@@@^&@@@@@^&@*@@@##@/. @%%^&/%%^&@@#@@@
echo @@@@@@^&@@@@@^&@@@@@^&^&@^&^&%%,.%%^&#^&^&^&%%*^&@@@^&^&^&^&^&,#@@@@^&^&^(.^&^&@@@@@^&@@^(@^&^&%%^&^&^&@^&@%%@*@@
timeout /t 2 >nul
echo  +============================================================================+
echo  ^|   CREDIT                                                                   ^|
echo  +============================================================================+
echo  ^|                                                                            ^|
echo  ^|   Mod created by TinyStormCloud                                            ^|
echo  ^|                                                                            ^|
echo  ^|   More Arc Raiders mods:                                                   ^|
echo  ^|   https://next.nexusmods.com/profile/TinyStormCloud/mods?gameId=8365       ^|
echo  ^|                                                                            ^|
echo  ^|   Support:                                                                 ^|
echo  ^|   https://next.nexusmods.com/profile/TinyStormCloud                        ^|
echo  ^|                                                                            ^|
echo  +============================================================================+
echo.
<nul set /p "=  Press any key..."
pause >nul
<nul set /p "=%ESC%[1G%ESC%[2KDON'T SHOOT^!^!"
pause >nul
<nul set /p "=%ESC%[1G%ESC%[2KSee you in Speranza Raider"
pause >nul
echo.
goto MENU

:EXIT
endlocal
exit /b 0
