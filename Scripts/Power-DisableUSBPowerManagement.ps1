# Title
Clear-Host
Write-Host ""
Write-Host "-----------------------------------------------------------------"
Write-Host "--------------- Jake Carter's Windows Script Kit ----------------"
Write-Host "------------------ Disable USB Power Management -----------------"
Write-Host "------------------ Based off ThioJoe's Script! ------------------"
Write-Host "-----------------------------------------------------------------"
Write-Host ""

# Disable USB's Power Management
Write-Host "Disabling USB's Power Management..."

# Config.
$ErrorActionPreference = 'Continue'
$VerbosePreference     = 'Continue'

# Counters.
$disabled  = 0
$skipped   = 0
$failed    = 0

Write-Host "Querying WMI — this may take a moment...`n"

# Gather Data.
# Win32_PnPEntity covers everything: USB hubs, controllers, composite devices,
# HID, serial-over-USB — nothing gets missed the way Win32_SerialPort or
# Win32_USBHub would.
try {
    $devices = Get-CimInstance -ClassName Win32_PnPEntity |
      Where-Object { $_.PNPDeviceID -ne $null }
} catch {
    Write-Error "Failed to query Win32_PnPEntity: $_"
    exit 1
}

try {
    $powerMgmt = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable
} catch {
    Write-Error "Failed to query MSPower_DeviceEnable: $_"
    exit 1
}

Write-Host "Found $($devices.Count) PnP devices and $($powerMgmt.Count) power management entries.`n"

# Main Loop
foreach ($p in $powerMgmt) {

    # Find the matching PnP device for this power entry
    $matchedDevice = $null
    foreach ($d in $devices) {
        # Escape so backslashes and other regex metacharacters in PNPDeviceIDs
        # (e.g. USB\VID_045E&PID_0823\...) don't cause false matches or errors
        $pattern = [regex]::Escape($d.PNPDeviceID)
        if ($p.InstanceName -match $pattern) {
            $matchedDevice = $d
            break
        }
    }

    # No matching device found for this power entry — skip silently
    if ($null -eq $matchedDevice) { continue }

    $label = "$($matchedDevice.Name) [$($matchedDevice.PNPDeviceID)]"

    if (-not $p.Enable) {
        Write-Verbose "Already disabled : $label"
        $skipped++
        continue
    }

    # Attempt to disable
    try {
        Set-CimInstance -InputObject $p -Property @{ Enable = $false } -ErrorAction Stop
        Write-Host "  [DISABLED] $label" -ForegroundColor Green
        $disabled++
    } catch {
        Write-Warning "  [FAILED]   $label`n             Reason: $_"
        $failed++
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Disabled : $disabled" -ForegroundColor Green
Write-Host "  Skipped  : $skipped"  -ForegroundColor Gray
Write-Host "  Failed   : $failed"   -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })
Write-Host ""

if ($failed -gt 0) {
    Write-Warning "Some devices could not be updated. Check the warnings above."
    exit 1
} else {
    Write-Host "Done. All applicable devices have USB power management disabled." -ForegroundColor Green

# End of Script
Write-Host ""
Write-Host "-----------------------------------------------------------------"
Write-Host "----------------------- Script completed! -----------------------"
Write-Host "-----------------------------------------------------------------"
Read-Host "Press 'Enter' to exit"
}
