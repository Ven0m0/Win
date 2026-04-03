# Common.ps1 - Shared utility functions for Windows optimization scripts
# This module provides reusable functions to avoid code duplication

#region Admin Elevation
function Request-AdminElevation {
    <#
    .SYNOPSIS
        Ensures the script is running with administrator privileges
    .DESCRIPTION
        Checks if the current session has admin rights. If not, relaunches the script with elevation
    #>
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
        Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
        Exit
    }
}
#endregion

#region UI Configuration
function Initialize-ConsoleUI {
    <#
    .SYNOPSIS
        Initializes console UI with consistent styling
    .PARAMETER Title
        The window title to set
    #>
    param(
        [string]$Title = $myInvocation.MyCommand.Definition + " (Administrator)"
    )

    $Host.UI.RawUI.WindowTitle = $Title
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.PrivateData.ProgressBackgroundColor = "Black"
    $Host.PrivateData.ProgressForegroundColor = "White"
    Clear-Host
}

function Show-Menu {
    <#
    .SYNOPSIS
        Displays a formatted menu
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of menu options
    #>
    param(
        [string]$Title,
        [string[]]$Options
    )

    Clear-Host
    if ($Title) {
        Write-Host $Title -ForegroundColor Cyan
        Write-Host ""
    }

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "$($i + 1). $($Options[$i])"
    }
    Write-Host ""
}

function Get-MenuChoice {
    <#
    .SYNOPSIS
        Gets and validates user menu choice
    .PARAMETER Min
        Minimum valid choice
    .PARAMETER Max
        Maximum valid choice
    #>
    param(
        [int]$Min = 1,
        [int]$Max
    )

    while ($true) {
        $choice = Read-Host "Select option ($Min-$Max)"
        if ($choice -match "^[$Min-$Max]$") {
            return [int]$choice
        }
        Write-Host "Invalid input. Please select a valid option ($Min-$Max)." -ForegroundColor Red
    }
}

function Wait-ForKeyPress {
    <#
    .SYNOPSIS
        Waits for user to press any key
    .PARAMETER Message
        Optional message to display before waiting
    .PARAMETER UseReadHost
        Use Read-Host instead of RawUI.ReadKey (useful for specific prompts)
    #>
    param(
        [string]$Message = "",
        [switch]$UseReadHost
    )

    if ($Message) {
        Write-Host $Message -NoNewline
    }

    if ($UseReadHost) {
        $null = Read-Host
    } else {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Show-RestartRequired {
    <#
    .SYNOPSIS
        Displays a restart required message and waits for user acknowledgment
    .PARAMETER CustomMessage
        Optional custom message (defaults to standard restart message)
    #>
    param(
        [string]$CustomMessage = "Restart required to apply changes..."
    )

    Write-Host $CustomMessage -ForegroundColor Yellow
    Wait-ForKeyPress
}
#endregion

#region Registry Helpers
function Set-RegistryValue {
    <#
    .SYNOPSIS
        Sets a registry value with error suppression
    .PARAMETER Path
        Registry path
    .PARAMETER Name
        Value name
    .PARAMETER Type
        Value type
    .PARAMETER Data
        Value data
    #>
    param(
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Data
    )

    $null = reg add $Path /v $Name /t $Type /d $Data /f 2>&1
}

function Remove-RegistryValue {
    <#
    .SYNOPSIS
        Removes a registry value with error suppression
    .PARAMETER Path
        Registry path
    .PARAMETER Name
        Value name
    #>
    param(
        [string]$Path,
        [string]$Name = $null
    )

    if ($Name) {
        $null = reg delete $Path /v $Name /f 2>&1
    } else {
        $null = reg delete $Path /f 2>&1
    }
}

function Get-NvidiaGpuRegistryPaths {
    <#
    .SYNOPSIS
        Gets all NVIDIA GPU registry paths
    .DESCRIPTION
        Returns registry paths for all NVIDIA display adapters
    #>
    $basePath = "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    $subkeys = (Get-ChildItem -Path "Registry::$basePath" -Force -ErrorAction SilentlyContinue).Name
    return $subkeys | Where-Object { $_ -notlike '*Configuration' }
}

$script:CachedNvidiaGpuPaths = $null

function Get-NvidiaGpuPaths {
  <#
  .SYNOPSIS
      Returns cached NVIDIA GPU registry paths
  .PARAMETER ForceRefresh
      Forces refresh of cached GPU registry paths
  #>
  param([switch]$ForceRefresh)

  if ($ForceRefresh -or -not $script:CachedNvidiaGpuPaths) {
    $script:CachedNvidiaGpuPaths = Get-NvidiaGpuRegistryPaths
  }

  return $script:CachedNvidiaGpuPaths
}

function Set-NvidiaGpuRegistryValue {
  <#
  .SYNOPSIS
      Sets a registry value for all NVIDIA GPUs
  .PARAMETER Name
      Registry value name
  .PARAMETER Type
      Registry value type
  .PARAMETER Data
      Registry value data
  .PARAMETER GpuPaths
      Optional GPU registry paths (uses cached paths when omitted)
  #>
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [string]$Type,
    [Parameter(Mandatory)]
    [string]$Data,
    [string[]]$GpuPaths
  )

  if (!$GpuPaths) {
    $GpuPaths = Get-NvidiaGpuPaths
  }

  foreach ($path in $GpuPaths) {
    Set-RegistryValue -Path $path -Name $Name -Type $Type -Data $Data
  }

  return $GpuPaths
}

function Get-NvidiaGpuSettings {
  <#
  .SYNOPSIS
      Retrieves NVIDIA GPU registry settings for display
  .PARAMETER Setting
      Filter to "All", "P0State", or "HDCP"
  .PARAMETER GpuPaths
      Optional GPU registry paths (uses cached paths when omitted)
  #>
  param(
    [string]$Setting = "All",
    [string[]]$GpuPaths
  )

  if (!$GpuPaths) {
    $GpuPaths = Get-NvidiaGpuPaths
  }

  $results = @()

  foreach ($path in $GpuPaths) {
    $gpuName = ($path -split '\\')[-1]
    $entry = [ordered]@{
      GpuName = $gpuName
      Path    = $path
      P0State = $null
      HDCP    = $null
    }

    if ($Setting -eq "All" -or $Setting -eq "P0State") {
      try {
        $entry.P0State = (Get-ItemProperty -Path "Registry::$path" -Name 'DisableDynamicPstate' -ErrorAction Stop).DisableDynamicPstate
      } catch {
        $entry.P0State = $null
      }
    }

    if ($Setting -eq "All" -or $Setting -eq "HDCP") {
      try {
        $entry.HDCP = (Get-ItemProperty -Path "Registry::$path" -Name 'RMHdcpKeyglobZero' -ErrorAction Stop).RMHdcpKeyglobZero
      } catch {
        $entry.HDCP = $null
      }
    }

    $results += [pscustomobject]$entry
  }

  return $results
}

function Show-NvidiaGpuSettings {
  <#
  .SYNOPSIS
      Displays NVIDIA GPU settings for all detected GPUs
  .PARAMETER Title
      Optional title for output
  .PARAMETER Setting
      Filter to "All", "P0State", or "HDCP"
  .PARAMETER GpuPaths
      Optional GPU registry paths (uses cached paths when omitted)
  #>
  param(
    [string]$Title = "Current NVIDIA GPU Settings:",
    [string]$Setting = "All",
    [string[]]$GpuPaths
  )

  $settings = Get-NvidiaGpuSettings -Setting $Setting -GpuPaths $GpuPaths

  Write-Host ""
  Write-Host $Title -ForegroundColor Yellow
  Write-Host ""

  foreach ($item in $settings) {
    Write-Host "GPU: $($item.GpuName)" -ForegroundColor Cyan

    if ($Setting -eq "All" -or $Setting -eq "P0State") {
      if ($null -ne $item.P0State) {
        Write-Host "  P0 State (DisableDynamicPstate): $($item.P0State)" -ForegroundColor Green
      } else {
        Write-Host "  P0 State: Not configured" -ForegroundColor Gray
      }
    }

    if ($Setting -eq "All" -or $Setting -eq "HDCP") {
      if ($null -ne $item.HDCP) {
        Write-Host "  HDCP (RMHdcpKeyglobZero): $($item.HDCP)" -ForegroundColor Green
      } else {
        Write-Host "  HDCP: Not configured" -ForegroundColor Gray
      }
    }

    Write-Host ""
  }
}

function Show-RegistryStatus {
    <#
    .SYNOPSIS
        Displays registry value status with color-coded output
    .PARAMETER Path
        Registry path (in PowerShell format like 'HKLM:\SOFTWARE\...')
    .PARAMETER Name
        Registry value name
    .PARAMETER Label
        Display label for the setting
    .PARAMETER EnabledValue
        Value that indicates "enabled" state
    .PARAMETER EnabledText
        Text to show when enabled (default: "Enabled")
    .PARAMETER DisabledText
        Text to show when disabled (default: "Disabled")
    .PARAMETER NotFoundText
        Text to show when not found (default: "Not configured")
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Label,
        [object]$EnabledValue = 1,
        [string]$EnabledText = "Enabled",
        [string]$DisabledText = "Disabled",
        [string]$NotFoundText = "Not configured"
    )

    if (!$Label) {
        $Label = $Name
    }

    try {
        $value = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name

        if ($value -eq $EnabledValue) {
            Write-Host "${Label}: " -NoNewline
            Write-Host $EnabledText -ForegroundColor Green
        } else {
            Write-Host "${Label}: " -NoNewline
            Write-Host $DisabledText -ForegroundColor Yellow
        }
    } catch {
        Write-Host "${Label}: " -NoNewline
        Write-Host $NotFoundText -ForegroundColor Gray
    }
}

function Get-RegistryValueSafe {
    <#
    .SYNOPSIS
        Safely retrieves a registry value with fallback
    .DESCRIPTION
        Attempts to read a registry value and returns $null if not found
        Eliminates need for repeated try-catch blocks
    .PARAMETER Path
        Registry path (in PowerShell format like 'HKLM:\SOFTWARE\...')
    .PARAMETER Name
        Registry value name
    .PARAMETER DefaultValue
        Value to return if registry key/value not found (default: $null)
    .EXAMPLE
        $value = Get-RegistryValueSafe -Path "HKLM:\SOFTWARE\Test" -Name "Setting"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [object]$DefaultValue = $null
    )

    try {
        $value = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        return $value
    } catch {
        return $DefaultValue
    }
}

function Set-NvidiaSignatureOverride {
  <#
  .SYNOPSIS
      Enables or disables NVIDIA driver signature override
  .PARAMETER Enabled
      $true to enable, $false to disable
  #>
  param([Parameter(Mandatory)][bool]$Enabled)

  $value = if ($Enabled) { "on" } else { "off" }
  $regData = if ($Enabled) { "01" } else { "00" }

  Write-Host "$(if ($Enabled) { 'Enabling' } else { 'Disabling' }) Driver Signature Override..." -ForegroundColor Cyan

  # BCDEDIT settings
  $bcdNoIntegrityOutput = & bcdedit.exe /set nointegritychecks $value 2>&1
  $bcdNoIntegrityExitCode = $LASTEXITCODE

  $bcdTestSigningOutput = & bcdedit.exe /set testsigning $value 2>&1
  $bcdTestSigningExitCode = $LASTEXITCODE

  if (($bcdNoIntegrityExitCode -eq 0) -and ($bcdTestSigningExitCode -eq 0)) {
    Write-Host "  ✓ BCDEDIT settings updated ($value)" -ForegroundColor Green
  } else {
    Write-Host "  ⚠️  Failed to update BCDEDIT settings (may require Secure Boot disabled or elevated PowerShell)" -ForegroundColor Yellow
    if ($bcdNoIntegrityExitCode -ne 0 -and $bcdNoIntegrityOutput) {
      Write-Host "    nointegritychecks error (exit code $bcdNoIntegrityExitCode):" -ForegroundColor Yellow
      Write-Host "      $bcdNoIntegrityOutput"
    }
    if ($bcdTestSigningExitCode -ne 0 -and $bcdTestSigningOutput) {
      Write-Host "    testsigning error (exit code $bcdTestSigningExitCode):" -ForegroundColor Yellow
      Write-Host "      $bcdTestSigningOutput"
    }
  }

  # NVIDIA Registry Keys
  $regError = $false
  Set-RegistryValue -Path "HKLM\SOFTWARE\NVIDIA Corporation\Global" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}" -Type "REG_BINARY" -Data $regData
  if ($LASTEXITCODE -ne 0) {
    $regError = $true
  }
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}" -Type "REG_BINARY" -Data $regData
  if ($LASTEXITCODE -ne 0) {
    $regError = $true
  }

  if (-not $regError) {
    Write-Host "  ✓ NVIDIA signature registry keys updated" -ForegroundColor Green
  } else {
    Write-Host "  ⚠️  Failed to update one or more NVIDIA signature registry keys" -ForegroundColor Yellow
  }
}

function Get-NvidiaSignatureStatus {
  <#
  .SYNOPSIS
      Returns status of NVIDIA signature override settings
  #>
  $status = [ordered]@{
    GlobalOverride  = $false
    ServiceOverride = $false
  }

  $globalVal = Get-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}"
  if ($null -ne $globalVal) {
    if ($globalVal -is [array]) {
      $status.GlobalOverride = $globalVal[0] -eq 1
    } else {
      $status.GlobalOverride = $globalVal -eq 1
    }
  }

  $serviceVal = Get-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}"
  if ($null -ne $serviceVal) {
    if ($serviceVal -is [array]) {
      $status.ServiceOverride = $serviceVal[0] -eq 1
    } else {
      $status.ServiceOverride = $serviceVal -eq 1
    }
  }

  return [pscustomobject]$status
}
#endregion

#region File Download
function Get-FileFromWeb {
    <#
    .SYNOPSIS
        Downloads a file from the web with progress indicator
    .PARAMETER URL
        The URL to download from
    .PARAMETER File
        The destination file path
    #>
    param(
        [Parameter(Mandatory)]
        [string]$URL,

        [Parameter(Mandatory)]
        [string]$File
    )

    function Show-Progress {
        param(
            [Parameter(Mandatory)][Single]$TotalValue,
            [Parameter(Mandatory)][Single]$CurrentValue,
            [Parameter(Mandatory)][string]$ProgressText,
            [Parameter()][int]$BarSize = 10,
            [Parameter()][switch]$Complete
        )

        $percent = $CurrentValue / $TotalValue
        $percentComplete = $percent * 100

        if ($psISE) {
            Write-Progress "$ProgressText" -id 0 -percentComplete $percentComplete
        } else {
            Write-Host -NoNewLine "`r$ProgressText $(''.PadRight($BarSize * $percent, [char]9608).PadRight($BarSize, [char]9617)) $($percentComplete.ToString('##0.00').PadLeft(6)) % "
        }
    }

    try {
        $request = [System.Net.HttpWebRequest]::Create($URL)
        $response = $request.GetResponse()

        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
            throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$URL'."
        }

        if ($File -match '^\.\\') {
            $File = Join-Path (Get-Location -PSProvider 'FileSystem') ($File -Split '^\.')[1]
        }

        if ($File -and !(Split-Path $File)) {
            $File = Join-Path (Get-Location -PSProvider 'FileSystem') $File
        }

        if ($File) {
            $fileDirectory = $([System.IO.Path]::GetDirectoryName($File))
            if (!(Test-Path($fileDirectory))) {
                [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
            }
        }

        [long]$fullSize = $response.ContentLength
        [byte[]]$buffer = New-Object byte[] 1048576
        [long]$total = [long]$count = 0

        $reader = $response.GetResponseStream()
        $writer = New-Object System.IO.FileStream $File, 'Create'

        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
            if ($fullSize -gt 0) {
                Show-Progress -TotalValue $fullSize -CurrentValue $total -ProgressText " $($File.Name)"
            }
        } while ($count -gt 0)
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Close() }
    }
}
#endregion

#region Network Helpers
function New-QueryString {
  <#
  .SYNOPSIS
      Converts a hashtable to a URL query string
  .DESCRIPTION
      Takes a hashtable of parameters and converts them into a URL-encoded query string.
      Keys are sorted alphabetically for deterministic output.
  .PARAMETER Parameters
      Hashtable of key-value pairs to encode
  .EXAMPLE
      New-QueryString -Parameters @{ id = 123; name = "test & run" }
  #>
  param(
    [Parameter(Mandatory)]
    [hashtable]$Parameters
  )

  if ($Parameters.Count -eq 0) { return "" }

  # Use ordinal sorting for deterministic, culture-independent key order
  $keys = @($Parameters.Keys)
  [System.Array]::Sort($keys, [System.StringComparer]::Ordinal)

  $queryParts = foreach ($key in $keys) {
    $value = $Parameters[$key]

    # Format key using invariant culture when possible
    if ($key -is [System.IFormattable]) {
      $keyString = $key.ToString($null, [System.Globalization.CultureInfo]::InvariantCulture)
    } else {
      $keyString = $key.ToString()
    }
    $encodedKey = [System.Net.WebUtility]::UrlEncode($keyString)

    if ($null -ne $value) {
      # Format value using invariant culture when possible
      if ($value -is [System.IFormattable]) {
        $valueString = $value.ToString($null, [System.Globalization.CultureInfo]::InvariantCulture)
      } else {
        $valueString = $value.ToString()
      }
      $encodedValue = [System.Net.WebUtility]::UrlEncode($valueString)
    } else {
      $encodedValue = ""
    }
    "$encodedKey=$encodedValue"
  }

  return $queryParts -join '&'
}
#endregion

#region Monitor Management
$script:CachedMonitorInstances = $null

function Get-MonitorInstances {
  <#
  .SYNOPSIS
      Retrieves all monitor instance paths from WMI
  .DESCRIPTION
      Returns monitor instance paths with optional caching to reduce WMI queries
  .PARAMETER ForceRefresh
      Forces refresh of cached monitor instances
  .EXAMPLE
      $monitors = Get-MonitorInstances
  #>
  param([switch]$ForceRefresh)

  if ($ForceRefresh -or -not $script:CachedMonitorInstances) {
    try {
      $script:CachedMonitorInstances = (Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction Stop).InstanceName -replace '_0', ''
    } catch {
      Write-Host "Error retrieving monitor information: $($_.Exception.Message)" -ForegroundColor Red
      $script:CachedMonitorInstances = @()
    }
  }

  return $script:CachedMonitorInstances
}
#endregion

#region Gaming Display Settings
function Set-FullscreenMode {
  <#
  .SYNOPSIS
      Configures fullscreen mode (FSO or FSE)
  .PARAMETER Mode
      'FSO' for Fullscreen Optimizations or 'FSE' for Fullscreen Exclusive
  #>
  param([string]$Mode)

  Clear-Host

  if ($Mode -eq 'FSO') {
    # Fullscreen Optimizations (Default)
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Type REG_DWORD -Data "0"
    Remove-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehavior"
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type REG_DWORD -Data "0"

    Write-Host "Fullscreen Optimizations (FSO) enabled." -ForegroundColor Green
  } else {
    # Fullscreen Exclusive
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Type REG_DWORD -Data "2"
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Type REG_DWORD -Data "2"
    Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type REG_DWORD -Data "1"

    Write-Host "Fullscreen Exclusive (FSE) enabled." -ForegroundColor Green
    Write-Host ""
    Write-Host "Additional steps may be required:" -ForegroundColor Yellow
    Write-Host "  1. Right-click game.exe"
    Write-Host "  2. Select Properties"
    Write-Host "  3. Go to Compatibility tab"
    Write-Host "  4. Check 'Disable fullscreen optimizations'"
    Write-Host "  5. Click Apply"
    Write-Host ""
    Write-Host "Note: DX12 engines do not support fullscreen exclusive mode." -ForegroundColor Cyan
  }
}

function Set-MultiPlaneOverlay {
  <#
  .SYNOPSIS
      Configures Multiplane Overlay and windowed game optimizations
  .PARAMETER Mode
      'Enabled', 'Disabled', or 'Default'
  #>
  param([string]$Mode)

  Clear-Host

  switch ($Mode) {
    'Enabled' {
      # Enable multiplane overlay
      Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"

      # Enable optimizations for windowed games
      Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;"

      Write-Host "Multiplane Overlay: Enabled" -ForegroundColor Green
      Write-Host "Windowed Game Optimizations: Enabled" -ForegroundColor Green
    }
    'Disabled' {
      # Disable multiplane overlay
      Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Type REG_DWORD -Data "5"

      # Disable optimizations for windowed games
      Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;"

      Write-Host "Multiplane Overlay: Disabled" -ForegroundColor Yellow
      Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Yellow
    }
    'Default' {
      # Enable multiplane overlay (default)
      Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"

      # Disable optimizations for windowed games
      Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;"

      Write-Host "Multiplane Overlay: Default (Enabled)" -ForegroundColor Cyan
      Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Cyan
    }
  }
}

function Show-GamingDisplayStatus {
  <#
  .SYNOPSIS
      Displays current gaming display settings
  #>
  Clear-Host
  Write-Host "Current Gaming Display Settings:" -ForegroundColor Cyan
  Write-Host ""

  # Check FSO/FSE settings
  $fseMode = Get-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode"
  if ($null -ne $fseMode) {
    if ($fseMode -eq 2) {
      Write-Host "Fullscreen Mode: FSE (Fullscreen Exclusive)" -ForegroundColor Green
    } else {
      Write-Host "Fullscreen Mode: FSO (Fullscreen Optimizations)" -ForegroundColor Green
    }
  } else {
    Write-Host "Fullscreen Mode: Not configured" -ForegroundColor Gray
  }

  # Check MPO settings
  $mpoTest = Get-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
  if ($null -ne $mpoTest) {
    if ($mpoTest -eq 5) {
      Write-Host "Multiplane Overlay: Disabled" -ForegroundColor Yellow
    } else {
      Write-Host "Multiplane Overlay: Enabled" -ForegroundColor Green
    }
  } else {
    Write-Host "Multiplane Overlay: Default (Enabled)" -ForegroundColor Green
  }

  # Check DirectX settings
  $dxSettings = Get-RegistryValueSafe -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings"
  if ($null -ne $dxSettings) {
    if ($dxSettings -like '*SwapEffectUpgradeEnable=1*') {
      Write-Host "Windowed Game Optimizations: Enabled" -ForegroundColor Green
    } else {
      Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Yellow
    }
  } else {
    Write-Host "Windowed Game Optimizations: Not configured" -ForegroundColor Gray
  }

  Write-Host ""
}
#endregion

#region VDF Parsing (for Steam scripts)
function ConvertFrom-VDF {
    <#
    .SYNOPSIS
        Parses Valve Data Format (VDF) files
    .PARAMETER Content
        VDF file content as string array
    .PARAMETER line
        Reference to the current line index used for recursive parsing
    #>
    param(
        [string[]]$Content,
        [ref]$line = ([ref]0)
    )
    $re = '\A\s*("(?<k>[^"]+)"|(?<b>[\{\}]))\s*(?<v>"(?:\\"|[^"])*")?\Z'
    $obj = [ordered]@{}

    while ($line.Value -lt $Content.Count) {
        if ($Content[$line.Value] -match $re) {
            if ($matches.k) { $key = $matches.k }
            if ($matches.v) { $obj[$key] = $matches.v }
            elseif ($matches.b -eq '{') { $line.Value++; $obj[$key] = ConvertFrom-VDF -Content $Content -line $line }
            elseif ($matches.b -eq '}') { break }
        }
        $line.Value++
    }

    return $obj
}

function ConvertTo-VDF {
    <#
    .SYNOPSIS
        Converts hashtable to VDF format
    .PARAMETER Data
        Hashtable to convert
    .PARAMETER Indent
        Current indentation level
    #>
    param($Data, [ref]$Indent = ([ref]0))

    if ($Data -isnot [System.Collections.Specialized.OrderedDictionary] -and $Data -isnot [hashtable]) {
        return
    }

    foreach ($key in $Data.Keys) {
        if ($Data[$key] -is [System.Collections.Specialized.OrderedDictionary] -or $Data[$key] -is [hashtable]) {
            $tabs = "`t" * $Indent.Value
            Write-Output "$tabs""$key`n$tabs{`n"
            $Indent.Value++
            ConvertTo-VDF -Data $Data[$key] -Indent $Indent
            $Indent.Value--
            Write-Output "$tabs}`n"
        } else {
            $tabs = "`t" * $Indent.Value
            Write-Output "$tabs""$key`t`t$($Data[$key])`n"
        }
    }
}
#endregion

#region Cleanup Helpers
function Clear-DirectorySafe {
    <#
    .SYNOPSIS
        Safely clears directory contents using robocopy or fallback
    .PARAMETER Path
        Directory to clear
    #>
    param([string]$Path)

    if (!(Test-Path $Path)) { return }

    $empty = "$Path\-EMPTY-"
    New-Item $empty -ItemType Directory -Force | Out-Null

    # Use robocopy for performance
    $null = robocopy "$empty" "$Path" /MIR /R:1 /W:0 /ZB /NFL /NDL /NJH /NJS 2>&1

    # Fallback
    Get-ChildItem "$Path" -Recurse -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}
#endregion


#region System Management
function New-RestorePoint {
  <#
  .SYNOPSIS
      Creates a system restore point
  .PARAMETER Description
      Restore point description
  #>
  param(
    [string]$Description = "Before Optimization"
  )

  Write-Host "Creating System Restore Point..." -ForegroundColor Yellow
  try {
    # Enable System Restore if not enabled
    Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue

    # Create restore point
    Checkpoint-Computer -Description "$Description $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Host "  Restore point created successfully" -ForegroundColor Green
  } catch {
    Write-Host "  Warning: Could not create restore point" -ForegroundColor Yellow
    Write-Host "  Error: $_" -ForegroundColor DarkGray
    Write-Host "  Continuing anyway..." -ForegroundColor Yellow
  }
}
#endregion

#region App Management
function Remove-AppxPackageSafe {
  <#
  .SYNOPSIS
      Safely removes an Appx package for all users and its provisioned counterpart
  .PARAMETER AppName
      Name or wildcard for the Appx package
  #>
  param(
    [Parameter(Mandatory)]
    [string]$AppName
  )

  $packages = Get-AppxPackage -Name $AppName -AllUsers 2>$null
  if ($packages) {
    foreach ($package in $packages) {
      Write-Host "  Removing: $($package.Name)" -ForegroundColor Yellow
      try {
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers 2>$null
      } catch {
        try {
          Remove-AppxPackage -Package $package.PackageFullName 2>$null
        } catch {
          Write-Host "    Failed to remove $($package.Name)" -ForegroundColor Red
        }
      }
    }
  }

  $provisioned = Get-AppxProvisionedPackage -Online 2>$null | Where-Object { $_.PackageName -like "*$AppName*" }
  if ($provisioned) {
    foreach ($package in $provisioned) {
      Write-Host "  Removing provisioned: $($package.DisplayName)" -ForegroundColor Yellow
      try {
        Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop
      } catch {
        Write-Host "    Failed to remove provisioned package $($package.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
      }
    }
  }
}
#endregion

#region EDID Override Management
function Set-EDIDOverride {
  <#
  .SYNOPSIS
      Applies EDID override to all monitors to fix display driver stuttering
  #>
  $regLocation = 'HKLM\SYSTEM\CurrentControlSet\Enum\'
  $edidHex = '02030400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7'
  $monitors = Get-MonitorInstances

  if ($monitors.Count -eq 0) {
    Write-Host "No monitors detected!" -ForegroundColor Yellow
    return
  }

  Write-Host "Applying EDID Override..." -ForegroundColor Cyan
  Write-Host ""

  foreach ($monitor in $monitors) {
    $name = $monitor -split '\\'
    Write-Host "  Applying override for: $($name[1])" -ForegroundColor Green
    $regPath = "$regLocation$monitor\Device Parameters\EDID_OVERRIDE"
    Set-RegistryValue -Path $regPath -Name '1' -Type REG_BINARY -Data $edidHex
  }

  Write-Host ""
  Write-Host "EDID override applied successfully to $($monitors.Count) monitor(s)." -ForegroundColor Green
}

function Remove-EDIDOverride {
  <#
  .SYNOPSIS
      Removes EDID override from all monitors
  #>
  $regLocation = 'HKLM\SYSTEM\CurrentControlSet\Enum\'
  $monitors = Get-MonitorInstances

  if ($monitors.Count -eq 0) {
    Write-Host "No monitors detected!" -ForegroundColor Yellow
    return
  }

  Write-Host "Removing EDID Override..." -ForegroundColor Cyan
  Write-Host ""

  foreach ($monitor in $monitors) {
    $name = $monitor -split '\\'
    Write-Host "  Removing override for: $($name[1])" -ForegroundColor Green
    $regPath = "$regLocation$monitor\Device Parameters\EDID_OVERRIDE"
    Remove-RegistryValue -Path $regPath
  }

  Write-Host ""
  Write-Host "EDID override removed successfully from $($monitors.Count) monitor(s)." -ForegroundColor Green
}

function Show-EDIDStatus {
  <#
  .SYNOPSIS
      Displays current EDID override status for all monitors
  #>
  $monitors = Get-MonitorInstances

  if ($monitors.Count -eq 0) {
    Write-Host "No monitors detected!" -ForegroundColor Yellow
    return
  }

  Write-Host "Current EDID Override Status:" -ForegroundColor Cyan
  Write-Host ""

  foreach ($monitor in $monitors) {
    $name = $monitor -split '\\'
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$monitor\Device Parameters\EDID_OVERRIDE"

    Write-Host "Monitor: $($name[1])" -ForegroundColor Yellow

    if (Test-Path $regPath) {
      try {
        $null = Get-ItemProperty -Path $regPath -Name '1' -ErrorAction Stop
        Write-Host "  Status: Override applied" -ForegroundColor Green
        Write-Host "  Value: Present" -ForegroundColor Green
      } catch {
        Write-Host "  Status: No override" -ForegroundColor Gray
      }
    } else {
      Write-Host "  Status: No override" -ForegroundColor Gray
    }
    Write-Host ""
  }
}
#endregion

#region MSI Mode
function Set-MSIMode {
  <#
  .SYNOPSIS
      Enables or disables MSI mode for all display adapters
  .PARAMETER Enable
      $true to enable MSI mode, $false to disable
  #>
  param([bool]$Enable)

  Clear-Host

  $gpuDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

  if ($gpuDevices.Count -eq 0) {
    Write-Host "No display adapters found!" -ForegroundColor Yellow
    return
  }

  $msiValue = if ($Enable) { "1" } else { "0" }
  $status = if ($Enable) { "Enabling" } else { "Disabling" }

  Write-Host "$status MSI Mode for all GPUs..." -ForegroundColor Cyan
  Write-Host ""

  foreach ($gpu in $gpuDevices) {
    $instanceID = $gpu.InstanceId
    $regPath = "HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    Set-RegistryValue -Path $regPath -Name "MSISupported" -Type REG_DWORD -Data $msiValue
  }

  Write-Host "MSI Mode Status:" -ForegroundColor Cyan
  Write-Host ""

  foreach ($gpu in $gpuDevices) {
    $instanceID = $gpu.InstanceId
    $regPath = "Registry::HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"

    Write-Host "Device: $($gpu.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  Instance ID: $instanceID" -ForegroundColor Gray

    try {
      $msiSupported = (Get-ItemProperty -Path $regPath -Name "MSISupported" -ErrorAction Stop).MSISupported
      $statusColor = if ($msiSupported -eq 1) { "Green" } else { "Yellow" }
      $statusText = if ($msiSupported -eq 1) { "Enabled (1)" } else { "Disabled (0)" }
      Write-Host "  MSI Mode: $statusText" -ForegroundColor $statusColor
    } catch {
      Write-Host "  MSI Mode: Not configured or error accessing registry" -ForegroundColor Red
    }
    Write-Host ""
  }
}
#endregion

# Export functions
        try { Export-ModuleMember -Function * } catch { }
