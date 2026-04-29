#Requires -Version 5.1
<#
.SYNOPSIS
    Arc Raiders - Skip Videos Mod (PowerShell)
.DESCRIPTION
    Removes intro, match, and quest video files from Arc Raiders
    to skip cutscenes. Place this script in the Arc Raiders
    installation directory and run.
.PARAMETER Option
    Menu option: 1=Intro, 2=Match, 3=Quest, 4=All, 5=Diagnostics, 6=Credit, 0=Exit
.NOTES
    Author:      TinyStormCloud
    Version:     1.15.0
    Repository:  https://next.nexusmods.com/profile/TinyStormCloud/mods
#>
param(
    [ValidateSet('1','2','3','4','5','6','0')]
    [string]$Option
)

$script:Warn = '[!]'
$script:Esc  = [char]27

function Find-ArcRaiders {
    # 1. Steam registry
    $steamPath = $null
    try {
        $steamPath = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop | Select-Object -ExpandProperty SteamPath
    } catch {}
    if (-not $steamPath) {
        try {
            $steamPath = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Valve\Steam' -Name InstallPath -ErrorAction Stop | Select-Object -ExpandProperty InstallPath
        } catch {}
    }
    if ($steamPath) {
        $steamPath = $steamPath.Replace('/', '\')
        $candidate = Join-Path $steamPath 'steamapps\common\Arc Raiders\PioneerGame'
        if (Test-Path $candidate) {
            return Split-Path $candidate -Parent
        }
    }

    # 2. Default Steam path
    $pf86 = ${env:ProgramFiles(x86)}
    $candidate = Join-Path $pf86 'Steam\steamapps\common\Arc Raiders\PioneerGame'
    if (Test-Path $candidate) {
        return Split-Path $candidate -Parent
    }

    # 3. Epic Games default
    $candidate = Join-Path $env:ProgramFiles 'Epic Games\Arc Raiders\PioneerGame'
    if (Test-Path $candidate) {
        return Split-Path $candidate -Parent
    }

    # 4. Script directory fallback
    $scriptDir = $PSScriptRoot
    if (Test-Path (Join-Path $scriptDir 'PioneerGame')) {
        return $scriptDir
    }

    return $null
}

function Remove-VideoFile {
    param([string]$Dir, [string]$FileName, [string]$Label = '')
    if (-not (Test-Path $Dir)) {
        Write-Host "  ${esc}[91m[X]${esc}[0m $($Label ? "$Label - " : '')Directory not found" -ForegroundColor Red
        return $false
    }
    $fullPath = Join-Path $Dir $FileName
    if (-not (Test-Path $fullPath)) {
        Write-Host "  ${esc}[93m!WARN!${esc}[0m $($Label ? "$Label - " : '')Already applied" -ForegroundColor Yellow
        return $true
    }
    try {
        Remove-Item $fullPath -Force -ErrorAction Stop
        Write-Host "  ${esc}[92m[v]${esc}[0m $($Label ? "$Label - " : '')Successfully applied" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ${esc}[91m[X]${esc}[0m $($Label ? "$Label - " : '')Failed to delete file" -ForegroundColor Red
        return $false
    }
}

function Remove-QuestFiles {
    $qDir = Join-Path $MoviesPath 'Quests'
    if (-not (Test-Path $qDir)) {
        Write-Host "  ${esc}[91m[X]${esc}[0m Skip Quest Videos - Directory not found" -ForegroundColor Red
        return
    }
    Write-Host "  ${esc}[92m[v]${esc}[0m Found directory" -ForegroundColor Green

    $questFiles = @(
        'Quest_Intro_A_Bad_Feeling.bk2',
        'QUEST_INTRO_Dormant_Barons.bk2',
        'QUEST_INTRO_Finders_Keepers.bk2',
        'Quest_Intro_Finders_Keepers_V1.bk2',
        'QUEST_INTRO_The_Root_of_the_matter.bk2',
        'QUEST_OUTRO_A bad feeling.bk2',
        'QUEST_OUTRO_Communication_Hideout.bk2',
        'QUEST_OUTRO_Echoes_of_Victory_Ridge.bk2',
        'QUEST_OUTRO_Into_the_Fray.bk2',
        'QUEST_OUTRO_Switching_the_Supply.bk2',
        'QUEST_OUTRO_SymbolOfUnification.bk2'
    )

    $found = 0
    foreach ($f in $questFiles) {
        if (Test-Path (Join-Path $qDir $f)) { $found++ }
    }

    if ($found -eq 0) {
        Write-Host "  ${esc}[93m!WARN!${esc}[0m Skip Quest Videos - Already applied" -ForegroundColor Yellow
        return
    }
    Write-Host "  ${esc}[92m[v]${esc}[0m Found $found of $($questFiles.Count) files" -ForegroundColor Green

    $deleted = 0
    foreach ($f in $questFiles) {
        $fp = Join-Path $qDir $f
        if (Test-Path $fp) {
            try {
                Remove-Item $fp -Force -ErrorAction Stop
                $deleted++
            } catch {}
        }
    }

    if ($deleted -eq $found) {
        Write-Host "  ${esc}[92m[v]${esc}[0m Skip Quest Videos - Successfully applied" -ForegroundColor Green
    } else {
        Write-Host "  ${esc}[91m[X]${esc}[0m Skip Quest Videos - Failed to delete files" -ForegroundColor Red
    }
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  +===============================================================+"
    Write-Host "  |   ${esc}[96m)${esc}[92m\${esc}[93m\${esc}[91m\${esc}[0m ARC RAIDERS - SKIP VIDEOS MOD by TinyStormCloud        |"
    Write-Host "  +===============================================================+"
    Write-Host "  |                                                               |"
    Write-Host "  |   1. Skip Intro Video                                         |"
    Write-Host "  |   2. Skip Match Video                                         |"
    Write-Host "  |   3. Skip Quest Videos                                        |"
    Write-Host "  |   4. Apply all                                                |"
    Write-Host "  |                                                               |"
    Write-Host "  |   5. Troubleshoot                                             |"
    Write-Host "  |   6. Credit                                                   |"
    Write-Host "  |                                                               |"
    Write-Host "  |   0. Exit                                                     |"
    Write-Host "  |                                                               |"
    Write-Host "  +===============================================================+"
    Write-Host "  |                                                      v1.15.0  |"
    Write-Host "  +===============================================================+"
    Write-Host ""
}

function Show-Diagnostics {
    Clear-Host
    Write-Host ""
    Write-Host "  +===============================================================+"
    Write-Host "  |   DIAGNOSTICS                                                 |"
    Write-Host "  +===============================================================+"
    Write-Host ""

    $gameDir = Join-Path $CurrentDir 'PioneerGame'
    if (Test-Path $gameDir) {
        Write-Host "      ${esc}[92m[v]${esc}[0m Arc Raiders directory: $CurrentDir" -ForegroundColor Green
    } else {
        Write-Host "      ${esc}[91m[X]${esc}[0m Arc Raiders directory not found" -ForegroundColor Red
    }

    if ($CurrentDir -match '^C:') {
        Write-Host "      ${esc}[93m!WARN!${esc}[0m Install directory is on C:\ drive" -ForegroundColor Yellow
    } else {
        Write-Host "      ${esc}[92m[v]${esc}[0m Install directory is not on C:\ drive" -ForegroundColor Green
    }

    if (Test-Path $MoviesPath) {
        Write-Host "      ${esc}[92m[v]${esc}[0m Found PioneerGame\Content\Movies" -ForegroundColor Green
    } else {
        Write-Host "      ${esc}[91m[X]${esc}[0m Missing PioneerGame\Content\Movies" -ForegroundColor Red
    }

    foreach ($d in @('FTUE', 'Frontend', 'Quests')) {
        $p = Join-Path $MoviesPath $d
        if (Test-Path $p) {
            Write-Host "      ${esc}[92m[v]${esc}[0m Found Movies\$d" -ForegroundColor Green
        } else {
            Write-Host "      ${esc}[91m[X]${esc}[0m Missing Movies\$d" -ForegroundColor Red
        }
    }

    if (Test-Path $MoviesPath) {
        $tmp = Join-Path $MoviesPath '_write_test.tmp'
        try {
            'test' | Out-File $tmp -Force -ErrorAction Stop
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Host "      ${esc}[92m[v]${esc}[0m Write permissions OK" -ForegroundColor Green
        } catch {
            Write-Host "      ${esc}[91m[X]${esc}[0m No write permissions - run as Administrator" -ForegroundColor Red
        }
    } else {
        Write-Host "      ${esc}[91m[X]${esc}[0m Cannot check write permissions - path missing" -ForegroundColor Red
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host "      ${esc}[92m[v]${esc}[0m Running as Administrator" -ForegroundColor Green
    } else {
        Write-Host "      ${esc}[93m!WARN!${esc}[0m Not running as Administrator" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  +===============================================================+"
    Write-Host "  |   TROUBLESHOOT                                                |"
    Write-Host "  +===============================================================+"
    Write-Host "  |                                                               |"
    Write-Host "  |   1. Place this script in correct install directory:          |"
    Write-Host "  |      Steam: \steamapps\common\Arc Raiders                     |"
    Write-Host "  |      Epic:  \Epic Games\Arc Raiders                           |"
    Write-Host "  |                                                               |"
    Write-Host "  |   2. If issues persist, try running as Administrator.         |"
    Write-Host "  |                                                               |"
    Write-Host "  |   3. Make sure Arc Raiders is version 1.15.0 or later.        |"
    Write-Host "  |                                                               |"
    Write-Host "  |   4. Restart PC after applying mod.                           |"
    Write-Host "  |                                                               |"
    Write-Host "  +===============================================================+"
    Write-Host ""
    Write-Host "  Press Enter to go back to menu..."
    Read-Host
}

function Show-Credit {
    Clear-Host
    Write-Host @"
                         @@@@@@@@@@@@@%%^&%%^&@@@@@@@^&@^&%%^&#*
                      @@^&@@@@@@@@@@^&@^&^&^&^&#@@@@@@@@%%^&^&#%%@^&%%
                    ^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@^&^&@^&^&^&^&^&^&
                   @@@^&@@@@@@@@@@@@@@@@^&@@@@@@@@@@@@@%%@^&@^&@^&^&
                  @@#%%@@@@@@@@@@@^&^&^&^&%%@%%@@@@@@@@@@@^&^&%%^&@@%%@%%^&/
                 *^&@@^&@@@@@@@@@@@@^&^&^&@@@@@@@@@@@@@@^&@^&@^&%%^&#@@#@^&,
                .%%^&@^&@@@@@@@@@@@@@@^&^&@@^&@@@@^&@^&@@@@@%%%%^&#@#^&@@#*
               ./#@^&@@@@^&@@@@@^&@^&@@@@^&^&%%%%^&^&^&^&^&^&%%@^&@^&^&^&@%%#@^&^&^(^&##
               %%@@%%@%%^&^&@@@@@@@@@@@@#@^&#%%^&^&^&#@@#@#^&^&^&@%%%%#%%@@^&^&#*
              /#@#@^&^&%%@^&@@@@@@@@@@@@%%%%#^(%%@^&%%^&@^&@%%%%^&#^&^&#@%%^&^&@^&@@%%*^(
              ^(%%/%%#@^&#@@@@@@@@@@@@@@^&^&^(^(^(^(^&%%%%@^&#@#^&^&@@%%%%@@%%#^&^(/*
             ,%%/#^(^(@^&^&@@@@@@@@@@@@@@^&^(^(///^(^(#%%%%@@@@@%%%%@@%%^&@@^&%%^&%%.
              *^&@^&%%^(%%@@@@@@@@@@@@@###^(/////%%(%%@^&@@@@@@@@%%^(#/@@@%%/*
               ^(%%@%%%%#@###/^(@@@@@@@@^&@@%%^(**/#@^&@@@@@@^&#%%^(*,^(^&@,%%.
                ,@^&^(@#,^&@^&@@@##@^&/%%%%^&^&%%/,.*^(^(%%#/#^(//^&*,**,.#,*%%,.
                 /@@@@,,^&^&#%%%%^&^&^&%%#^(^(#%%#*... ..,/^(**. ....   ^(@@*
                 ^&@@@@%% *%%#^(^(*^(///#%%%%^(,      . . ......  ^&@@@@^(
                ^(@@@@@@..*^&%%#^(^(^(/**^(%%%%/.      ... ....   .@@@@/.
                @@@@@@^&*//^(#%%#^(//*/%%%%%%%%%/*,..  ....      @@@@^&@^(
                %%@@@@@@ *#%%%%%%%%%##/////##...              /@@@@@##
               %%@@@@@@   ,^&^&^&%%%%#^(^(^(##^&^&*%%^&.  .        * @@@@@@@
               ^&@@@@@@*    ^&^&^&^&%%%%##%%^&%%#^(%%/*/*.,*,.. ..   @@@@@@,
               %%@@@@@@,      ^&%%^&%%%%%%@%%#%%^(*,,,,,..,    *@@@@@^&%%
               @@@@@@@      //@^(/%%%%^(*,,..........    . ^(@@@@@^&@
               ^&^&@@@@@    //^&^&^&^&^&^&,%%#^(/*///*,....  ..,^& * @@^&^&@@#
              ^&@@@@@@    /.*##^&^&^&%%%%^&%%^&^&%%^(/*,.. .,.,     /@@@@@@@/
              ^&@@@@@@  .^(../%%^(##^(@##^(^(^(^(/**,....,       ,,,@^&@@@%%^(
              %%@@@@@#*@@.,*//##^(^(**,./,,,,,,,/           .*@@@@@^&,
              ^&@@@@@@@@@**//^(*,,......  .                #@@@@@@%%^&
            #@@@@@@@@@@@,,*,,,.  ..   @@^(^&/               @@%%@@@%%@/^&%%#
 @@@@@@@*%%*@@^(%%@@^&@@@@@^&.,,,,....    ^&^&^&@@@@,            *@%%#@@@^(@@^&#%%%%^&#@^&@^&#^&@
 @@@@@@@@@@%%@@@@@@/@@#@@@@,*,... .   ^&@^&@@^&^&@@/           @@#@@@@@@@@@^&##@@@^&@@@
 @@@@@@@@@@@@@@^&@%%@@@@@*^&@*,,,...   ^(@@@@^&@%%*@@         @@@/%%#@@/,@@@^&^&^&,^&@^&@@@@
 @^&@*@@@*@@@@@%%^&@@#^&@@@@@@@,,. .   @@@@@@@%%^&^&@@@@^(      *@@@@^&^(@@%%@@@#/@%%^&^&^&^&@@@
 @^&@@@@@@@^&#@@^(@@%%^&@@@*^(^&@@@.,.  .^&@^&@@@*@@^&^&@@@@@@     ^&^&@@@#@@@@.,@@%%%%^&@^&%%#@@@
 ^&@@@@@@@@@@@@^(@@*^&@@@@@^&^&@^&@. ^&^&^&^&^&@@#.@.@^&^&@@@@@^&@@@@@^&@*@@@##@/. @%%^&/%%^&@@#@@@
 @@@@@@@@@#@@^&/@^&^&@@@@#^(^&^&@^&@. %%^&#^&^&^&%%*^&@@@^&^&^&^&^&,#@@@@^&^&^(.^&^&@@@@@^&@@^(@^&^&%%^&^&^&@^&@%%@*@@
 @@@@@@^&@@@@@^&@@@@@^&^&@^&^&%%,.%%^&#^&^&^&%%*^&@@@^&^&^&^&^&^&^&,#@@@@^&^&^(.^&^&@@@@@^&@@^(@^&^&%%^&^&^&@^&@%%@*@@
"@
    Start-Sleep -Seconds 2
    Write-Host "  +============================================================================+"
    Write-Host "  |   CREDIT                                                                   |"
    Write-Host "  +============================================================================+"
    Write-Host "  |                                                                            |"
    Write-Host "  |   Mod created by TinyStormCloud                                            |"
    Write-Host "  |                                                                            |"
    Write-Host "  |   More Arc Raiders mods:                                                   |"
    Write-Host "  |   https://next.nexusmods.com/profile/TinyStormCloud/mods?gameId=8365       |"
    Write-Host "  |                                                                            |"
    Write-Host "  |   Support:                                                                 |"
    Write-Host "  |   https://next.nexusmods.com/profile/TinyStormCloud                        |"
    Write-Host "  |                                                                            |"
    Write-Host "  +============================================================================+"
    Write-Host ""
    Write-Host "  DON'T SHOOT!!"
    Start-Sleep -Seconds 1
    Write-Host "`rSee you in Speranza Raider   "
    Start-Sleep -Seconds 1
    Write-Host ""
    Write-Host "  Press Enter to go back to menu..."
    Read-Host
}

# ── Main ──────────────────────────────────────────────────────────────────────
$CurrentDir = Find-ArcRaiders
if (-not $CurrentDir) {
    Write-Host ""
    Write-Host "      [X] ARC RAIDERS NOT FOUND" -ForegroundColor Red
    Write-Host ""
    Write-Host "      Could not locate Arc Raiders automatically."
    Write-Host "      Place this script in the Arc Raiders installation directory."
    Write-Host ""
    Write-Host "      Searched:"
    Write-Host "      - Steam registry"
    Write-Host "      - ${env:ProgramFiles(x86)}\Steam\steamapps\common\Arc Raiders"
    Write-Host "      - $env:ProgramFiles\Epic Games\Arc Raiders"
    Write-Host ""
    exit 1
}

$MoviesPath = Join-Path $CurrentDir 'PioneerGame\Content\Movies'

if ($Option) {
    # Non-interactive mode
    switch ($Option) {
        '1' { Remove-VideoFile (Join-Path $MoviesPath 'FTUE') 'GAME_INTRO_SPERANZA_DESCEND_V5.bk2' 'Skip Intro Video' }
        '2' { Remove-VideoFile (Join-Path $MoviesPath 'Frontend') 'LaunchSequence_ToBlack_4k.bk2' 'Skip Match Video' }
        '3' { Remove-QuestFiles }
        '4' {
            Remove-VideoFile (Join-Path $MoviesPath 'FTUE') 'GAME_INTRO_SPERANZA_DESCEND_V5.bk2' 'Skip Intro Video'
            Remove-VideoFile (Join-Path $MoviesPath 'Frontend') 'LaunchSequence_ToBlack_4k.bk2' 'Skip Match Video'
            Remove-QuestFiles
        }
        '5' { Show-Diagnostics; return }
        '6' { Show-Credit; return }
        '0' { exit 0 }
    }
    return
}

# Interactive menu loop
while ($true) {
    Show-Menu
    $choice = Read-Host "   Select an option"
    switch ($choice) {
        '1' {
            Clear-Host
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host "  |   ${esc}[96m)${esc}[92m\${esc}[93m\${esc}[91m\${esc}[0m APPLYING SKIP INTRO VIDEO MOD                          |"
            Write-Host "  +===============================================================+"
            Write-Host ""
            Remove-VideoFile (Join-Path $MoviesPath 'FTUE') 'GAME_INTRO_SPERANZA_DESCEND_V5.bk2' 'Skip Intro Video'
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host ""
            Write-Host "  Press Enter to go back to menu..."
            Read-Host
        }
        '2' {
            Clear-Host
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host "  |   ${esc}[96m)${esc}[92m\${esc}[93m\${esc}[91m\${esc}[0m APPLYING SKIP MATCH VIDEO MOD                          |"
            Write-Host "  +===============================================================+"
            Write-Host ""
            Remove-VideoFile (Join-Path $MoviesPath 'Frontend') 'LaunchSequence_ToBlack_4k.bk2' 'Skip Match Video'
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host ""
            Write-Host "  Press Enter to go back to menu..."
            Read-Host
        }
        '3' {
            Clear-Host
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host "  |   ${esc}[93m!WARN!${esc}[0m WARNING                                                 |"
            Write-Host "  +===============================================================+"
            Write-Host ""
            Write-Host "      This mod is intended for players who have finished their"
            Write-Host "      first playthrough and have done the expedition, and"
            Write-Host "      don't want to rewatch quest videos."
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host ""
            $confirm = Read-Host "   Do you want to continue? (Y/N)"
            if ($confirm -ieq 'Y') {
                Clear-Host
                Write-Host ""
                Write-Host "  +===============================================================+"
                Write-Host "  |   ${esc}[96m)${esc}[92m\${esc}[93m\${esc}[91m\${esc}[0m APPLYING SKIP QUEST VIDEOS MOD                         |"
                Write-Host "  +===============================================================+"
                Write-Host ""
                Remove-QuestFiles
                Write-Host ""
                Write-Host "  +===============================================================+"
                Write-Host ""
            }
            Write-Host "  Press Enter to go back to menu..."
            Read-Host
        }
        '4' {
            Clear-Host
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host "  |   ${esc}[93m!WARN!${esc}[0m WARNING                                                 |"
            Write-Host "  +===============================================================+"
            Write-Host ""
            Write-Host "      This will apply all mods. Skip Quest Videos is intended"
            Write-Host "      for players who have finished their first playthrough and"
            Write-Host "      have done their expedition, and don't want to rewatch"
            Write-Host "      story videos."
            Write-Host ""
            Write-Host "  +===============================================================+"
            Write-Host ""
            $confirm = Read-Host "   Do you want to continue? (Y/N)"
            if ($confirm -ieq 'Y') {
                Clear-Host
                Write-Host ""
                Write-Host "  +===============================================================+"
                Write-Host "  |   ${esc}[96m)${esc}[92m\${esc}[93m\${esc}[91m\${esc}[0m APPLYING ALL MODS                                      |"
                Write-Host "  +===============================================================+"
                Write-Host ""
                Remove-VideoFile (Join-Path $MoviesPath 'FTUE') 'GAME_INTRO_SPERANZA_DESCEND_V5.bk2' 'Skip Intro Video'
                Remove-VideoFile (Join-Path $MoviesPath 'Frontend') 'LaunchSequence_ToBlack_4k.bk2' 'Skip Match Video'
                Remove-QuestFiles
                Write-Host ""
                Write-Host "  +===============================================================+"
                Write-Host ""
            }
            Write-Host "  Press Enter to go back to menu..."
            Read-Host
        }
        '5' { Show-Diagnostics }
        '6' { Show-Credit }
        '0' { exit 0 }
        default {
            Write-Host ""
            Write-Host "  ${esc}[91m[X]${esc}[0m Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
