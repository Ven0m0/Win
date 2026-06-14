#Requires -Version 5.1

<#
.SYNOPSIS
    Unified Steam management: configure, launch, create shortcuts, clean caches, manage WebHelper.
.DESCRIPTION
    Consolidates steam.ps1, Steam-Config.ps1, New-SteamShortcut.ps1, and Optimize-Steam.ps1.

    Actions:
      Configure               Apply performance settings to Steam localconfig.vdf.
      Launch                  Stop and restart Steam with optimized launch arguments.
      CreateShortcut          Create an optimized Steam desktop shortcut.
      CleanRedist             Remove redistributable installer cache files.
      InstallNoSteamWebHelper Install NoSteamWebHelper DLL (umpdc.dll) to reduce CPU/RAM.
      RestoreNoSteamWebHelper Restore the original umpdc.dll from backup.
      All                     Configure + CleanRedist + InstallNoSteamWebHelper + CreateShortcut.
.PARAMETER Action
    Action to perform. Defaults to All.
.PARAMETER SteamPath
    Custom Steam installation path. Auto-detected from registry when omitted.
.PARAMETER Mode
    Launch/configure mode: Default (small mode, no GPU) or ArcRaiders (full mode).
.PARAMETER ShortcutName
    Name for the desktop shortcut (default: "Steam (Optimized)").
.PARAMETER ConfigPaths
    Override localconfig.vdf paths for the Configure action. Auto-detected when omitted.
.PARAMETER DryRun
    Show what would be done without making changes.
.EXAMPLE
    .\Optimize-Steam.ps1
.EXAMPLE
    .\Optimize-Steam.ps1 -Action Configure
.EXAMPLE
    .\Optimize-Steam.ps1 -Action Launch -Mode ArcRaiders
.EXAMPLE
    .\Optimize-Steam.ps1 -Action CleanRedist -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Configure', 'Launch', 'CreateShortcut', 'CleanRedist',
                 'InstallNoSteamWebHelper', 'RestoreNoSteamWebHelper', 'All')]
    [string]$Action = 'All',
    [string]$SteamPath,
    [ValidateSet('Default', 'ArcRaiders')]
    [string]$Mode = 'Default',
    [string]$ShortcutName = 'Steam (Optimized)',
    [string[]]$ConfigPaths,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"

#region VDF parser - class-based for Configure / preserved for Steam-Config tests
class vdfnode { [System.Collections.Generic.List[object]]$entries = [System.Collections.Generic.List[object]]::new() }

class vdfentry {
    [string]$kind
    [string]$name
    [string]$value
    [vdfnode]$node
    vdfentry([string]$kind, [string]$name, [string]$value, [vdfnode]$node) {
        $this.kind = $kind; $this.name = $name; $this.value = $value; $this.node = $node
    }
}

function readstr([string]$text, [ref]$pos) {
    $chars = [System.Collections.Generic.List[char]]::new(); $null = $pos.Value++
    while ($pos.Value -lt $text.Length) {
        $char = $text[$pos.Value]
        if ($char -eq '\') {
            if ($pos.Value + 1 -ge $text.Length) { throw 'unterminated escape sequence' }
            $pos.Value++; $chars.Add($text[$pos.Value]); $null = $pos.Value++; continue
        }
        if ($char -eq '"') { $null = $pos.Value++; return -join $chars }
        $chars.Add($char); $null = $pos.Value++
    }
    throw 'unterminated string'
}

function skipws([string]$text, [ref]$pos) {
    while ($pos.Value -lt $text.Length) {
        $char = $text[$pos.Value]
        if ([char]::IsWhiteSpace($char)) { $null = $pos.Value++; continue }
        if ($char -eq '/' -and $pos.Value + 1 -lt $text.Length -and $text[$pos.Value + 1] -eq '/') {
            while ($pos.Value -lt $text.Length -and $text[$pos.Value] -notin "`r", "`n") { $null = $pos.Value++ }
            continue
        }
        break
    }
}

function parseobj([string]$text, [ref]$pos) {
    $node = [vdfnode]::new()
    while ($true) {
        skipws $text $pos
        if ($pos.Value -ge $text.Length) { throw 'unexpected end of file' }
        if ($text[$pos.Value] -eq '}') { $null = $pos.Value++; return $node }
        if ($text[$pos.Value] -ne '"') { throw "expected key at offset $($pos.Value)" }
        $name = readstr $text $pos; skipws $text $pos
        if ($pos.Value -ge $text.Length) { throw "missing value for '$name'" }
        if ($text[$pos.Value] -eq '{') {
            $null = $pos.Value++
            $node.entries.Add([vdfentry]::new('block', $name, $null, (parseobj $text $pos)))
            continue
        }
        if ($text[$pos.Value] -ne '"') { throw "expected string or block for '$name'" }
        $node.entries.Add([vdfentry]::new('value', $name, (readstr $text $pos), $null))
    }
}

function parsevdf([string]$text) {
    $pos = 0; skipws $text ([ref]$pos)
    if ($pos -ge $text.Length -or $text[$pos] -ne '"') { throw 'missing root key' }
    $name = readstr $text ([ref]$pos); skipws $text ([ref]$pos)
    if ($pos -ge $text.Length -or $text[$pos] -ne '{') { throw 'missing root block' }
    $pos++
    $tree = [pscustomobject]@{ name = $name; node = parseobj $text ([ref]$pos) }
    skipws $text ([ref]$pos)
    if ($pos -lt $text.Length) { throw "unexpected trailing content at offset $pos" }
    $tree
}

function esc([string]$text) { $text.Replace('\', '\\').Replace('"', '\"') }

function writenode([vdfnode]$node, [int]$depth) {
    $lines = [System.Collections.Generic.List[string]]::new(); $pad = "`t" * $depth
    foreach ($entry in $node.entries) {
        $name = esc $entry.name
        if ($entry.kind -eq 'value') {
            $lines.Add($pad + '"' + $name + '"' + "`t`t" + '"' + (esc $entry.value) + '"'); continue
        }
        $lines.Add($pad + '"' + $name + '"'); $lines.Add($pad + '{')
        foreach ($line in writenode $entry.node ($depth + 1)) { $lines.Add($line) }
        $lines.Add($pad + '}')
    }
    $lines
}

function writevdf($tree) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('"' + (esc $tree.name) + '"'); $lines.Add('{')
    foreach ($line in writenode $tree.node 1) { $lines.Add($line) }
    $lines.Add('}')
    [string]::Join("`r`n", $lines) + "`r`n"
}

function findentry([vdfnode]$node, [string]$name) {
    for ($i = 0; $i -lt $node.entries.Count; $i++) { if ($node.entries[$i].name -ceq $name) { return $i } }
    -1
}

function ensureblock([vdfnode]$node, [string]$name) {
    $i = findentry $node $name
    if ($i -ge 0) {
        $entry = $node.entries[$i]
        if ($entry.kind -ne 'block') { throw "expected '$name' to be a block" }
        return $entry.node
    }
    $child = [vdfnode]::new()
    $node.entries.Add([vdfentry]::new('block', $name, $null, $child))
    $child
}

function setvalue([vdfnode]$node, [string]$name, [string]$value) {
    $i = findentry $node $name
    if ($i -ge 0) {
        $entry = $node.entries[$i]
        if ($entry.kind -ne 'value') { throw "expected '$name' to be a value" }
        $entry.value = $value
        return
    }
    $node.entries.Add([vdfentry]::new('value', $name, $value, $null))
}
#endregion

#region Configure settings - script-scoped so Steam-Config tests can reference $settings
$settings = [ordered]@{
    Broadcast    = [ordered]@{ Permissions = '0'; FirstTimeComplete = '1' }
    system       = [ordered]@{
        displayratesasbits                  = '0'
        EnableGameOverlay                   = '0'
        InGameOverlayRestoreBrowserTabs     = '0'
        InGameOverlayScreenshotNotification = '0'
        InGameOverlayScreenshotPlaySound    = '0'
        NetworkingAllowShareIP              = '1'
    }
    streaming_v2 = [ordered]@{ EnableStreaming = '0' }
    friends      = [ordered]@{ SignIntoFriends = '0' }
    GameRecording = [ordered]@{ BackgroundRecordMode = '0' }
    news         = [ordered]@{ NotifyAvailableGames = '0' }
    root         = [ordered]@{
        LibraryLowBandwidthMode        = '1'
        LibraryLowPerfMode             = '1'
        LibraryDisableCommunityContent = '1'
        ReadyToPlayIncludesStreaming    = '0'
        SteamController_Enable_Chord   = '0'
        Controller_CheckGuideButton    = '0'
        SteamController_PSSupport      = '0'
        SmallMode                      = '1'
    }
    Accessibility = [ordered]@{ ReduceMotion = '1' }
}
#endregion

#region Configure
function Invoke-Configure {
    <#
    .SYNOPSIS
        Applies performance settings to Steam localconfig.vdf for all user accounts.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SteamPath,
        [string[]]$Paths,
        [ValidateSet('Default', 'ArcRaiders')]
        [string]$SteamMode = 'Default'
    )

    if (-not $Paths) {
        $pattern = Join-Path $SteamPath 'userdata\*\config\localconfig.vdf'
        $Paths = @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | ForEach-Object FullName)
    }

    if (-not $Paths) {
        Write-Warning "No localconfig.vdf files found under $SteamPath\userdata"
        return
    }

    # Clone settings so we can adjust SmallMode per mode without mutating the script-level var
    $cfg = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($k in $settings.Keys) { $cfg[$k] = $settings[$k] }
    $cfg['root'] = [ordered]@{} + $settings['root']
    $cfg['root']['SmallMode'] = if ($SteamMode -eq 'ArcRaiders') { '0' } else { '1' }

    foreach ($path in $Paths) {
        if (-not $PSCmdlet.ShouldProcess($path, 'Apply Steam config')) { continue }

        if (Test-Path $path) {
            $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
            $tree = parsevdf $text
        } else {
            $tree = [pscustomobject]@{ name = 'UserLocalConfigStore'; node = [vdfnode]::new() }
        }

        if ($tree.name -ne 'UserLocalConfigStore') {
            Write-Warning "Unexpected root key '$($tree.name)' in $path - skipping"
            continue
        }

        $root = $tree.node
        foreach ($scope in $cfg.Keys) {
            $node = if ($scope -eq 'root') { $root } else { ensureblock $root $scope }
            foreach ($name in $cfg[$scope].Keys) { setvalue -node $node -name $name -value $cfg[$scope][$name] }
        }

        if (Test-Path $path) { [System.IO.File]::Copy($path, "$path.bak", $true) }
        $tmp = "$path.tmp"
        [System.IO.File]::WriteAllText($tmp, (writevdf $tree), [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tmp -Destination $path -Force
        Write-ColorOutput "  Configured: $path" -ForegroundColor Green
    }
}
#endregion

#region Launch
function Invoke-Launch {
    <#
    .SYNOPSIS
        Stops Steam (if running) then restarts it with optimized launch arguments.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SteamPath,
        [ValidateSet('Default', 'ArcRaiders')]
        [string]$SteamMode = 'Default'
    )

    $steamExe = Join-Path $SteamPath 'Steam.exe'
    if (-not (Test-Path $steamExe)) {
        Write-Warning "Steam not found at: $SteamPath"
        return
    }

    $noGPU = ($SteamMode -ne 'ArcRaiders')

    $launchArgs = '-silent -quicklogin -forceservice -vrdisable -oldtraymenu -nofriendsui -no-dwrite -nojoy -noshaders'
    if ($noGPU) { $launchArgs += ' -nodirectcomp -cef-disable-gpu -cef-disable-gpu-sandbox' }
    $launchArgs += ' -cef-allow-browser-underlay -cef-delaypageload -cef-force-occlusion -cef-disable-hang-timeouts -console'

    $wasRunning = $null -ne (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)
    if ($wasRunning) {
        Stop-SteamGracefully
        Remove-Item -Path (Join-Path $SteamPath '.crash') -Force -ErrorAction SilentlyContinue
        $launchArgs += ' -foreground'
    }

    if ($PSCmdlet.ShouldProcess($steamExe, "Start Steam ($SteamMode)")) {
        Write-ColorOutput "Starting Steam ($SteamMode)..." -ForegroundColor Cyan
        Start-Process -FilePath $steamExe -ArgumentList $launchArgs
    }
}
#endregion

#region CreateShortcut
function Invoke-CreateShortcut {
    <#
    .SYNOPSIS
        Creates an optimized Steam desktop shortcut.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SteamPath,
        [string]$Name = 'Steam (Optimized)',
        [switch]$DryRun
    )

    $steamExe = Join-Path $SteamPath 'Steam.exe'
    if (-not (Test-Path $steamExe)) {
        Write-Warning "Steam not found at: $SteamPath"
        return
    }

    $launchArgs = '-nofriendsui -nointro -nobigpicture -cef-single-process -cef-disable-breakpad' +
                  ' -cef-disable-gpu-compositing -cef-disable-gpu -cef-disable-js-logging -noconsole' +
                  ' +open steam://open/minigameslist'

    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "$Name.lnk"

    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] Shortcut: $shortcutPath" -ForegroundColor Yellow
        Write-ColorOutput "[DRY RUN] Target:   $steamExe" -ForegroundColor Yellow
        return
    }

    if ($PSCmdlet.ShouldProcess($shortcutPath, 'Create Steam shortcut')) {
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($shortcutPath)
        $lnk.TargetPath       = $steamExe
        $lnk.Arguments        = $launchArgs
        $lnk.Description      = 'Steam (Optimized) - performance-focused launch'
        $lnk.WorkingDirectory = $SteamPath
        $lnk.Save()
        Write-ColorOutput "Shortcut created: $shortcutPath" -ForegroundColor Green
    }
}
#endregion

#region CleanRedist
function Invoke-CleanRedist {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SteamPath)

    if (-not (Test-Path "$SteamPath\Steam.exe")) {
        Write-Warning "Steam not found at: $SteamPath"
        return
    }

    Write-ColorOutput "Cleaning Steam redistributable installer caches..." -ForegroundColor Cyan

    $redistPaths = @(
        "$SteamPath\steamapps\common\Steamworks Shared\_CommonRedist\DirectX",
        "$SteamPath\steamapps\common\Steamworks Shared\_CommonRedist\vcredist"
    )

    $totalFreed = 0
    foreach ($path in $redistPaths) {
        if (Test-Path $path) {
            $files = @(Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue)
            $filesRemoved = 0
            if ($files.Count -gt 0) {
                $beforeSize = ($files | Measure-Object -Property Length -Sum).Sum
                foreach ($file in $files) {
                    if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove installer file')) {
                        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                        $filesRemoved++
                    }
                }
                $afterSize = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                $freed = $beforeSize - ($afterSize -or 0)
                $totalFreed += $freed
            }
            if ($filesRemoved -gt 0) {
                Write-ColorOutput "  Removed $filesRemoved file(s) from $($path.Split('\')[-2,-1] -join '\')" `
                    -ForegroundColor Green
                if ($freed -gt 1MB) {
                    Write-ColorOutput "    Freed $([math]::Round($freed/1MB, 2)) MB" -ForegroundColor Gray
                }
            }
        }
    }

    if ($totalFreed -gt 0) {
        Write-ColorOutput "Total space freed: $([math]::Round($totalFreed/1MB, 2)) MB" -ForegroundColor Green
    } else {
        Write-ColorOutput "No installer files found to clean" -ForegroundColor Yellow
    }
}
#endregion

#region NoSteamWebHelper
function Invoke-InstallNoSteamWebHelper {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SteamPath)

    $targetDll = Join-Path $SteamPath 'umpdc.dll'
    $backupDll = "$targetDll.bak"

    if ($PSCmdlet.ShouldProcess('Download NoSteamWebHelper DLL')) {
        Write-ColorOutput "Downloading NoSteamWebHelper DLL..." -ForegroundColor Cyan
        Write-Warning "This modifies Steam's Web Helper DLL. Steam features (Store, Community) may not work afterward."

        try {
            $url     = 'https://github.com/Aetopia/NoSteamWebHelper/releases/latest/download/umpdc.dll'
            $tempDll = Join-Path $env:TEMP 'umpdc.dll'

            Get-FileFromWeb -URL $url -File $tempDll

            $fileSize = (Get-Item -Path $tempDll).Length
            if ($fileSize -lt 100kb) {
                Remove-Item -Path $tempDll -Force -ErrorAction SilentlyContinue
                throw "Downloaded file too small ($fileSize bytes)"
            }

            if ((Test-Path $targetDll) -and -not (Test-Path $backupDll)) {
                Copy-Item -Path $targetDll -Destination $backupDll -Force
                Write-ColorOutput "  Backed up original DLL to umpdc.dll.bak" -ForegroundColor Yellow
            }

            Copy-Item -Path $tempDll -Destination $targetDll -Force
            Remove-Item -Path $tempDll -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "NoSteamWebHelper installed successfully" -ForegroundColor Green
            Write-Warning "Steam Web Helper disabled. Some features (Store, Community) may not work."
        } catch {
            Write-Warning "Failed to download NoSteamWebHelper: $_"
        }
    }
}

function Invoke-RestoreNoSteamWebHelper {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SteamPath)

    $targetDll = Join-Path $SteamPath 'umpdc.dll'
    $backupDll = "$targetDll.bak"

    if (Test-Path $backupDll) {
        if ($PSCmdlet.ShouldProcess('Restore original DLL')) {
            Copy-Item -Path $backupDll -Destination $targetDll -Force
            Remove-Item -Path $backupDll -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "NoSteamWebHelper removed, original DLL restored" -ForegroundColor Green
        }
    } elseif (Test-Path $targetDll) {
        if ($PSCmdlet.ShouldProcess('Remove NoSteamWebHelper DLL')) {
            Remove-Item -Path $targetDll -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "NoSteamWebHelper DLL removed" -ForegroundColor Green
        }
    } else {
        Write-ColorOutput "NoSteamWebHelper DLL not found" -ForegroundColor Yellow
    }
}
#endregion

#region Main
if ($MyInvocation.InvocationName -ne '.') {
    Write-ColorOutput "Steam Optimization" -ForegroundColor Cyan
    Write-ColorOutput ""

    $resolvedPath = Get-SteamPath -Override $SteamPath
    Write-ColorOutput "Steam path: $resolvedPath"

    if ($Action -ne 'RestoreNoSteamWebHelper') {
        if (-not (Test-Path (Join-Path $resolvedPath 'Steam.exe'))) {
            Write-Warning "Steam not found at: $resolvedPath. Specify -SteamPath."
            exit 1
        }
    }

    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] No changes will be made" -ForegroundColor Yellow
        Write-ColorOutput ""
    }

    switch ($Action) {
        'Configure'               { Invoke-Configure -SteamPath $resolvedPath -Paths $ConfigPaths -SteamMode $Mode }
        'Launch'                  { Invoke-Launch -SteamPath $resolvedPath -SteamMode $Mode }
        'CreateShortcut'          { Invoke-CreateShortcut -SteamPath $resolvedPath -Name $ShortcutName -DryRun:$DryRun }
        'CleanRedist'             { Invoke-CleanRedist -SteamPath $resolvedPath }
        'InstallNoSteamWebHelper' { Invoke-InstallNoSteamWebHelper -SteamPath $resolvedPath }
        'RestoreNoSteamWebHelper' { Invoke-RestoreNoSteamWebHelper -SteamPath $resolvedPath }
        'All' {
            Invoke-Configure -SteamPath $resolvedPath -Paths $ConfigPaths -SteamMode $Mode
            Write-ColorOutput ""
            Invoke-CleanRedist -SteamPath $resolvedPath
            Write-ColorOutput ""
            Invoke-InstallNoSteamWebHelper -SteamPath $resolvedPath
            Write-ColorOutput ""
            Invoke-CreateShortcut -SteamPath $resolvedPath -Name $ShortcutName -DryRun:$DryRun
        }
    }

    Write-ColorOutput ""
    Write-ColorOutput "Done!" -ForegroundColor Green
    exit $LASTEXITCODE
}
#endregion
