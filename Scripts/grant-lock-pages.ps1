#Requires -Version 5
<#
  Grants "Lock pages in memory" (SeLockMemoryPrivilege) to the current user,
  required for the JVM's -XX:+UseLargePages to actually engage.
  Self-elevates, merges (does not overwrite) existing privilege holders.
  Log out / back in (or reboot) after running for it to take effect.
#>

# --- self-elevate ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psExe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $psExe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    )
    exit
}

$ErrorActionPreference = 'Stop'
$priv = 'SeLockMemoryPrivilege'
$sid  = ([Security.Principal.NTAccount]"$env:USERNAME").Translate([Security.Principal.SecurityIdentifier]).Value
Write-Host "Account: $env:USERNAME  ($sid)"

$work = Join-Path $env:TEMP 'lpim_grant'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$inf = Join-Path $work 'userrights.inf'
$db  = Join-Path $work 'userrights.sdb'

secedit /export /areas USER_RIGHTS /cfg $inf | Out-Null
$content = Get-Content $inf

$found = $false
$already = $false
$new = foreach ($l in $content) {
    if ($l -match "^\s*$priv\s*=") {
        $found = $true
        $sids = ($l -split '=', 2)[1].Trim()
        if ($sids -match [regex]::Escape($sid)) { $already = $true; $l }
        else { "$priv = $sids,*$sid" }
    } else { $l }
}
if (-not $found) {
    $new = foreach ($l in $content) {
        $l
        if ($l -match '^\[Privilege Rights\]') { "$priv = *$sid" }
    }
}

if ($already) {
    Write-Host "Already granted to $env:USERNAME. No change needed." -ForegroundColor Green
} else {
    Set-Content -Path $inf -Value $new -Encoding Unicode
    secedit /configure /db $db /cfg $inf /areas USER_RIGHTS | Out-Null
    Write-Host "Granted '$priv' to $env:USERNAME." -ForegroundColor Green
    Write-Host "Log out and back in (or reboot) for it to take effect." -ForegroundColor Yellow
}
Read-Host 'Press Enter to close'
