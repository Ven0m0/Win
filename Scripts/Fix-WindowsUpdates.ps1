#Requires -Version 5.1

<#
.SYNOPSIS
    Repairs Windows Update components safely.
.DESCRIPTION
    Ports the safe operations from ShadowWhisperer/Fix-WinUpdates into a
    PowerShell script with -WhatIf support, proper error handling, and
    Common.ps1 helper integration.  Does NOT reboot automatically.
.PARAMETER Restore
    If set, removes the registry tweaks applied by this script.
.EXAMPLE
    .\Fix-WindowsUpdates.ps1
.EXAMPLE
    .\Fix-WindowsUpdates.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Restore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Ensure Common.ps1 is available (best-effort in standalone usage)
# ---------------------------------------------------------------------------
$commonPath = Join-Path $PSScriptRoot 'Common.ps1'
if (Test-Path $commonPath) {
    . $commonPath
}

# ---------------------------------------------------------------------------
# Helper: run an external command and surface non-zero exits as warnings
# ---------------------------------------------------------------------------
function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string]$ArgumentList = ''
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $ArgumentList
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $null = $proc.Start()
    $proc.WaitForExit()

    if ($proc.ExitCode -ne 0) {
        $stderr = $proc.StandardError.ReadToEnd()
        Write-Warning "$FilePath exited $($proc.ExitCode) : $stderr"
    }
}

# ---------------------------------------------------------------------------
# Service reset
# ---------------------------------------------------------------------------
function Reset-WUService {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$StartupType = 'auto'
    )

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Verbose "Service '$Name' not found; skipping."
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Stop service')) {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
    }

    if ($PSCmdlet.ShouldProcess($Name, "Set startup type to $StartupType")) {
        $null = sc.exe config $Name start= $StartupType
    }
}

# ---------------------------------------------------------------------------
# Clear update caches
# ---------------------------------------------------------------------------
function Clear-UpdateCache {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $paths = @(
        'C:\Windows\Temp'
        'C:\Windows\Prefetch'
        'C:\Windows\SoftwareDistribution'
        "$env:ALLUSERSPROFILE\application data\Microsoft\Network\downloader"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            if ($PSCmdlet.ShouldProcess($path, 'Clear directory')) {
                try {
                    Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "Could not fully clear $path : $_"
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Reset catroot2
# ---------------------------------------------------------------------------
function Reset-Catroot2 {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $catroot = "$env:SystemRoot\system32\catroot2"
    if ($PSCmdlet.ShouldProcess($catroot, 'Reset catroot2')) {
        try {
            if (Test-Path $catroot) {
                Remove-Item $catroot -Recurse -Force -ErrorAction SilentlyContinue
            }
            $null = New-Item -ItemType Directory -Path $catroot -Force
        } catch {
            Write-Warning "Could not reset catroot2 : $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Re-register WU DLLs
# ---------------------------------------------------------------------------
function Register-WuDlls {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $dlls = @(
        'atl.dll'
        'msxml2.dll'
        'msxml3.dll'
        'msxml.dll'
        'wuaueng1.dll'
        'wuaueng.dll'
        'wucltui.dll'
        'wups2.dll'
        'wups.dll'
        'wuweb.dll'
    )

    foreach ($dll in $dlls) {
        $full = Join-Path $env:SystemRoot "System32\$dll"
        if (Test-Path $full) {
            if ($PSCmdlet.ShouldProcess($dll, 'regsvr32 /s')) {
                Invoke-ExternalCommand -FilePath 'regsvr32.exe' -ArgumentList "/s `"$full`""
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Registry tweaks
# ---------------------------------------------------------------------------
function Set-WURegistryTweaks {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $tweaks = @(
        # Disable "Get updates ASAP"
        @{ Path = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; Name = 'IsContinuousInnovationOptedIn'; Type = 'REG_DWORD'; Data = '0' }
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'AllowOptionalContent'; Type = 'REG_DWORD'; Data = '0' }
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetAllowOptionalContent'; Type = 'REG_DWORD'; Data = '0' }
    )

    foreach ($tweak in $tweaks) {
        if ($PSCmdlet.ShouldProcess("$($tweak.Path)\$($tweak.Name)", 'Set registry value')) {
            reg.exe add "`"$($tweak.Path)`"" /v $tweak.Name /t $tweak.Type /d $tweak.Data /f *>$null
        }
    }
}

function Remove-WURegistryTweaks {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $keys = @(
        @{ Path = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; Name = 'IsContinuousInnovationOptedIn' }
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'AllowOptionalContent' }
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetAllowOptionalContent' }
    )

    foreach ($key in $keys) {
        if ($PSCmdlet.ShouldProcess("$($key.Path)\$($key.Name)", 'Remove registry value')) {
            reg.exe delete "`"$($key.Path)`"" /v $key.Name /f *>$null
        }
    }
}

# ---------------------------------------------------------------------------
# Remove target-release constraints
# ---------------------------------------------------------------------------
function Remove-TargetReleaseConstraints {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $values = @(
        'TargetReleaseVersionInfo'
        'TargetReleaseVersion'
        'ProductVersion'
        'DisableOSUpgrade'
        'DisableWindowsUpdateAccess'
        'DoNotConnectToWindowsUpdateInternetLocations'
    )

    foreach ($value in $values) {
        if ($PSCmdlet.ShouldProcess("HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\$value", 'Delete')) {
            reg.exe delete '"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"' /v $value /f *>$null
        }
    }

    if ($PSCmdlet.ShouldProcess('HKLM\SOFTWARE\Policies\Microsoft\WindowsStore\DisableOSUpgrade', 'Delete')) {
        reg.exe delete '"HKLM\SOFTWARE\Policies\Microsoft\WindowsStore"' /v DisableOSUpgrade /f *>$null
    }

    if ($PSCmdlet.ShouldProcess('HKLM\SYSTEM\Setup\UpgradeNotification\UpgradeAvailable', 'Delete')) {
        reg.exe delete '"HKLM\SYSTEM\Setup\UpgradeNotification"' /v UpgradeAvailable /f *>$null
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ($Restore) {
    Write-Host 'Restoring Windows Update registry tweaks...' -ForegroundColor Cyan
    Remove-WURegistryTweaks
    Write-Host 'Restore complete.' -ForegroundColor Green
    return
}

Write-Host 'Fixing Windows Update components...' -ForegroundColor Cyan

# 1. Stop services
Reset-WUService -Name 'BITS' -StartupType 'delayed-auto'
Reset-WUService -Name 'wuauserv' -StartupType 'auto'
Reset-WUService -Name 'AppReadiness' -StartupType 'manual'
Reset-WUService -Name 'CryptSvc' -StartupType 'auto'

# 2. Clear caches
Clear-UpdateCache

# 3. Reset catroot2
Reset-Catroot2

# 4. Re-register DLLs
Register-WuDlls

# 5. Reset BITS & winsock
if ($PSCmdlet.ShouldProcess('BITS', 'Reset')) {
    Invoke-ExternalCommand -FilePath 'bitsadmin.exe' -ArgumentList '/reset /allusers'
}
if ($PSCmdlet.ShouldProcess('winsock', 'Reset')) {
    Invoke-ExternalCommand -FilePath 'netsh.exe' -ArgumentList 'winsock reset'
}

# 6. Registry tweaks
Set-WURegistryTweaks
Remove-TargetReleaseConstraints

# 7. gpupdate
if ($PSCmdlet.ShouldProcess('Group Policy', 'Update')) {
    Invoke-ExternalCommand -FilePath 'gpupdate.exe' -ArgumentList '/force'
}

Write-Host ''
Write-Host 'Windows Update repair complete. A reboot is recommended.' -ForegroundColor Green
Write-Host 'Run this script with -WhatIf to preview changes.' -ForegroundColor Gray
