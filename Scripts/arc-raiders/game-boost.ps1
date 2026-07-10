#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Arc Raiders — Game Boost (thin wrapper)
.DESCRIPTION
    Delegates to the generic Start-OptimizedGame engine with the Arc Raiders
    manifest. See Scripts/start-optimized-game.ps1 and Scripts/games/arc-raiders.psd1.
.PARAMETER NoLaunch
    Apply boost only — do not launch the game (use if game is already running).
.PARAMETER NoRestore
    Do not restore killed processes or power plan on exit.
.PARAMETER DryRun
    Show what would be killed/changed without actually doing it.
.EXAMPLE
    .\game-boost.ps1               # Boost + launch
    .\game-boost.ps1 -NoLaunch    # Boost only (game already running)
    .\game-boost.ps1 -DryRun      # Preview mode
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$NoLaunch,
    [switch]$NoRestore,
    [switch]$DryRun
)

if ($MyInvocation.InvocationName -eq '.') { return }

& "$PSScriptRoot\..\start-optimized-game.ps1" `
    -GameManifest "$PSScriptRoot\..\games\arc-raiders.psd1" `
    -NoLaunch:$NoLaunch -NoRestore:$NoRestore -DryRun:$DryRun -WhatIf:$WhatIfPreference
