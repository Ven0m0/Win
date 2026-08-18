#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Helium browser extensions from the Chrome Web Store without user interaction.

.DESCRIPTION
    Helium (imput) is a Chromium fork. Two install mechanisms are supported, both
    verified against the strings compiled into Helium 0.15.5.1 chrome.dll:

      External   HKLM:\SOFTWARE\Google\Chrome\Extensions\<id>\update_url
                 Helium's compiled-in external-extension registry root. Extensions are
                 fetched on next launch, prompt once via the "external install" bubble,
                 and remain user-disableable and user-removable. Default.

      Forcelist  HKLM:\SOFTWARE\Policies\Helium\ExtensionInstallForcelist
                 Enterprise policy. Installs silently with no prompt, but marks the
                 browser as managed and the extensions cannot be removed from the UI.

    Neither mechanism restores extension settings. Restore those separately by copying
    "Local Extension Settings", "Sync Extension Settings" and the per-extension
    IndexedDB directories into the profile with Helium closed.

.PARAMETER Id
    Extension IDs to install. Defaults to helium-extensions.txt beside this script if
    present, otherwise to the built-in list.

.PARAMETER Method
    External (default) or Forcelist. See above.

.PARAMETER Uninstall
    Remove the registry entries created by the chosen method instead of adding them.

.PARAMETER Export
    Do not install. Write the IDs and names of the extensions currently installed in the
    local Helium profile to helium-extensions.txt beside this script, then exit.

.EXAMPLE
    .\Install-HeliumExtensions.ps1
.EXAMPLE
    .\Install-HeliumExtensions.ps1 -Method Forcelist
.EXAMPLE
    .\Install-HeliumExtensions.ps1 -Export
#>
[CmdletBinding()]
param(
    [string[]]$Id,
    [ValidateSet('External', 'Forcelist')]
    [string]$Method = 'External',
    [switch]$Uninstall,
    [switch]$Export
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$UpdateUrl   = 'https://clients2.google.com/service/update2/crx'
$ExternalKey = 'HKLM:\SOFTWARE\Google\Chrome\Extensions'
$PolicyKey   = 'HKLM:\SOFTWARE\Policies\Helium'
$UserData    = Join-Path $env:LOCALAPPDATA 'imput\Helium\User Data'
$ListFile    = Join-Path $PSScriptRoot 'helium-extensions.txt'

$DefaultIds = [ordered]@{
    'ajopnjidmegmdimjlfnijceegpefgped' = 'BetterTTV'
    'bnomihfieiccainjcjblhegjgglakjdd' = 'Improve YouTube!'
    'dhdgffkkebhmkfjojejmpbldmpobfkfo' = 'Tampermonkey'
    'effdbpeggelllpfkjppbokhmmiinhlmg' = 'Better Lyrics'
    'faeadnfmdfamenfhaipofoffijhlnkif' = 'Into The Black Hole (theme)'
    'hhinaapppaileiechjoiifaancjggfjm' = 'Web Scrobbler'
    'hlepfoohegkhhmjieoechaddaejaokhf' = 'Refined GitHub'
    'mnjggcdmjocbbbhaepdhchncahnbgone' = 'SponsorBlock'
    'nngceckbapebfimnlniiiahkandclblb' = 'Bitwarden'
}

function Test-Admin {
    $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-InstalledExtension {
    $root = Join-Path $UserData 'Default\Extensions'
    if (-not (Test-Path $root)) { throw "Helium profile not found: $root" }
    foreach ($dir in Get-ChildItem $root -Directory) {
        if ($dir.Name -notmatch '^[a-p]{32}$') { continue }
        $ver = Get-ChildItem $dir.FullName -Directory -ErrorAction SilentlyContinue |
               Sort-Object Name | Select-Object -Last 1
        if (-not $ver) { continue }
        $name = $dir.Name
        try {
            $mf = Get-Content (Join-Path $ver.FullName 'manifest.json') -Raw | ConvertFrom-Json
            $name = $mf.name
            if ($name -match '^__MSG_(.+)__$') {
                $key = $Matches[1]
                $loc = if ($mf.PSObject.Properties['default_locale']) { $mf.default_locale } else { 'en' }
                $msg = Join-Path $ver.FullName "_locales\$loc\messages.json"
                if (Test-Path $msg) {
                    $name = (Get-Content $msg -Raw | ConvertFrom-Json).$key.message
                }
            }
        } catch {
            Write-Verbose "Failed to read manifest for extension $($dir.Name): $($_.Exception.Message)"
        }
        [pscustomobject]@{ Id = $dir.Name; Name = $name }
    }
}

function Resolve-Ids {
    if ($Id) { return $Id }
    if (Test-Path $ListFile) {
        $fromFile = Get-Content $ListFile |
            ForEach-Object { ($_ -split '#')[0].Trim() } |
            Where-Object { $_ -match '^[a-p]{32}$' }
        if ($fromFile) { return @($fromFile) }
    }
    return @($DefaultIds.Keys)
}

function Install-External {
    param([string[]]$Ids)
    foreach ($e in $Ids) {
        $key = Join-Path $ExternalKey $e
        if ($Uninstall) {
            if (Test-Path $key) { Remove-Item $key -Recurse -Force; "removed  $e" }
            else { "absent   $e" }
        } else {
            New-Item $key -Force | Out-Null
            New-ItemProperty $key -Name 'update_url' -Value $UpdateUrl -PropertyType String -Force | Out-Null
            "queued   $e"
        }
    }
}

function Install-Forcelist {
    param([string[]]$Ids)
    $key = Join-Path $PolicyKey 'ExtensionInstallForcelist'
    if ($Uninstall) {
        if (Test-Path $key) { Remove-Item $key -Recurse -Force; 'removed  ExtensionInstallForcelist' }
        else { 'absent   ExtensionInstallForcelist' }
        return
    }
    New-Item $key -Force | Out-Null
    Get-Item $key | Select-Object -ExpandProperty Property |
        ForEach-Object { Remove-ItemProperty $key -Name $_ -Force }
    $n = 1
    foreach ($e in $Ids) {
        New-ItemProperty $key -Name "$n" -Value "$e;$UpdateUrl" -PropertyType String -Force | Out-Null
        "forced   $e"
        $n++
    }
}

if ($Export) {
    $found = @(Get-InstalledExtension)
    if (-not $found) { Write-Warning 'No extensions found in the Helium profile.'; return }
    $lines = @(
        '# Helium extension IDs. Lines are "<id>  # <name>"; comments after # are ignored.'
        "# Exported $(Get-Date -Format 'yyyy-MM-dd HH:mm') from $UserData"
    ) + ($found | ForEach-Object { '{0}  # {1}' -f $_.Id, $_.Name })
    Set-Content -Path $ListFile -Value $lines -Encoding UTF8
    $found | Format-Table -AutoSize
    "Wrote $($found.Count) IDs to $ListFile"
    return
}

if (-not (Test-Admin)) {
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Method', $Method)
    if ($Id) { $argv += @('-Id') + $Id }
    if ($Uninstall) { $argv += '-Uninstall' }
    Write-Host 'Elevating...' -ForegroundColor Yellow
    Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $argv
    return
}

if (-not (Test-Path $UserData)) {
    Write-Warning "Helium profile not found at $UserData. Registry entries will still be written."
}

$ids = Resolve-Ids
Write-Host "$($ids.Count) extension(s), method=$Method, uninstall=$($Uninstall.IsPresent)" -ForegroundColor Cyan

switch ($Method) {
    'External'  { Install-External  -Ids $ids }
    'Forcelist' { Install-Forcelist -Ids $ids }
}

if (-not $Uninstall) {
    Write-Host ''
    Write-Host 'Done. Restart Helium to trigger installation.' -ForegroundColor Green
    if ($Method -eq 'External') {
        Write-Host 'Each extension will ask for a one-time confirmation in the browser.'
    }
    Write-Host 'Settings are not restored; re-import Tampermonkey scripts and sign in to Bitwarden.'
} else {
    Write-Host ''
    Write-Host 'Registry entries removed. Already-installed extensions stay until removed in Helium.' -ForegroundColor Green
}
