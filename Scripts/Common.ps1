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

#region VDF Parsing (for Steam scripts)
function ConvertFrom-VDF {
    <#
    .SYNOPSIS
        Parses Valve Data Format (VDF) files
    .PARAMETER Content
        VDF file content as string array
    #>
    param([string[]]$Content)

    [ref]$line = 0
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
