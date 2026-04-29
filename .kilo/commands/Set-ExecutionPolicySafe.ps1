#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Set PowerShell execution policy safely for this repository.
.DESCRIPTION
    Manages PowerShell execution policy with repository-aware defaults.
    Options: RemoteSigned (recommended), AllSigned, Restricted, or restore to system default.
    Can also toggle script execution on/off for the current user scope.
.PARAMETER Policy
    Execution policy to set: RemoteSigned (default), AllSigned, Restricted, Unrestricted, or Undefined.
.PARAMETER Scope
    Policy scope: CurrentUser (default, no admin required) or LocalMachine (requires admin).
.PARAMETER Get
    Display current execution policy for all scopes.
.PARAMETER Reset
    Reset to PowerShell defaults (Undefined at CurrentUser).
.EXAMPLE
    .\Set-ExecutionPolicySafe.ps1
    # Sets RemoteSigned at CurrentUser scope
.EXAMPLE
    .\Set-ExecutionPolicySafe.ps1 -Policy AllSigned -Scope LocalMachine
.EXAMPLE
    .\Set-ExecutionPolicySafe.ps1 -Get
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ParameterSetName = 'Set')]
    [ValidateSet('RemoteSigned', 'AllSigned', 'Restricted', 'Unrestricted', 'Undefined')]
    [string]$Policy = 'RemoteSigned',

    [Parameter(ParameterSetName = 'Set')]
    [ValidateSet('CurrentUser', 'LocalMachine')]
    [string]$Scope = 'CurrentUser',

    [Parameter(ParameterSetName = 'Get')]
    [switch]$Get,

    [Parameter(ParameterSetName = 'Reset')]
    [switch]$Reset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

Write-Host '=== PowerShell Execution Policy ===' -ForegroundColor Cyan

switch ($PSCmdlet.ParameterSetName) {
    'Get' {
        Write-Host '  Current execution policies by scope:' -ForegroundColor Gray
        $scopes = @('Process', 'CurrentUser', 'LocalMachine')
        foreach ($s in $scopes) {
            $current = Get-ExecutionPolicy -Scope $s -ErrorAction SilentlyContinue
            Write-Host "    $s`: $current"
        }
        # Effective policy for this session
        $effective = Get-ExecutionPolicy
        Write-Host "`n  Effective for this session: $effective" -ForegroundColor Yellow
        exit 0
    }

    'Reset' {
        Write-Host '  Resetting to default (Undefined at CurrentUser)...' -ForegroundColor Yellow
        if ($PSCmdlet.ShouldProcess('CurrentUser', 'Reset execution policy to Undefined')) {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Undefined -Force
            Write-Host '  Reset complete. Effective policy will be inherited from parent scopes.' -ForegroundColor Green
        }
        exit 0
    }

    default {
        # Set policy
        Write-Host "  Setting: $Policy at $Scope scope" -ForegroundColor Cyan

        # Check admin requirement for LocalMachine
        if ($Scope -eq 'LocalMachine') {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )
            if (-not $isAdmin) {
                Write-Error "LocalMachine scope requires administrator. Relaunch as admin."
                exit 1
            }
        }

        # Validate policy compatibility with script signing requirements
        if ($Policy -eq 'AllSigned' -and -not (Get-AuthenticodeSignature $MyInvocation.MyCommand).SignerCertificate) {
            Write-Warning "  AllSigned requires all scripts to be signed. Repository scripts are not signed by default."
            $confirmation = Read-Host 'Continue anyway? (y/N)'
            if ($confirmation -ne 'y') { exit 0 }
        }

        if ($PSCmdlet.ShouldProcess("$Scope", "Set execution policy to $Policy")) {
            try {
                Set-ExecutionPolicy -Scope $Scope -ExecutionPolicy $Policy -Force -ErrorAction Stop
                Write-Host "  Policy set: $Policy ($Scope)" -ForegroundColor Green

                # Verify
                $actual = Get-ExecutionPolicy -Scope $Scope
                Write-Host "  Verified: $actual" -ForegroundColor Gray

                # Show effective
                $effective = Get-ExecutionPolicy
                Write-Host "  Effective: $effective" -ForegroundColor Yellow

                if ($Policy -eq 'RemoteSigned' -and $Scope -eq 'CurrentUser') {
                    Write-Host '`n  Repository scripts can now run.' -ForegroundColor Green
                    Write-Host '  Next: run .\Deploy-Configs.ps1 to apply dotfiles' -ForegroundColor Gray
                }
            } catch {
                Write-Error "Failed to set policy: $_"
                exit 1
            }
        }
    }
}
