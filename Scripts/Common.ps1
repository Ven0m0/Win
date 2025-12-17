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

# Export functions
Export-ModuleMember -Function *
