## PowerShell Profile
# Location: $HOME\.dotfiles\config\powershell\Microsoft.PowerShell_profile.ps1
# Managed by dotbot

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true' `
        , [System.EnvironmentVariableTarget]::Machine)
}
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'
$env:VCPKG_DISABLE_METRICS = 'true'

# Async init queue: defers heavy prompt/module startup to idle time so the prompt appears
# instantly. One queued step runs per PowerShell.OnIdle tick; the subscription
# self-unregisters once the queue drains.
[System.Collections.Queue]$global:__initQueue = [System.Collections.Queue]::new()
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $__initQueue.Enqueue({
        . ([scriptblock]::Create((oh-my-posh init pwsh --config (Join-Path $env:USERPROFILE ".config\ohmyposh\cobalt2.omp.json") | Out-String)))
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    })
}
if (Get-Command mise -ErrorAction SilentlyContinue) {
    $__initQueue.Enqueue({
        $miseInit = (& mise activate pwsh) | Out-String
        if ($miseInit) { . ([scriptblock]::Create($miseInit)) }
    })
}
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    $__initQueue.Enqueue({
        try {
            Import-Module -Name Terminal-Icons -ErrorAction Stop
        } catch {
            # Terminal-Icons rewrites its theme cache on every load and re-reads it without
            # guarding against a partial/concurrent write, which throws a corrupt-CLIXML error.
            # The cache is regenerated from built-in data, so clearing it and retrying is a
            # lossless self-heal.
            $tiCache = Join-Path $env:APPDATA 'powershell\Community\Terminal-Icons'
            Remove-Item -Path (Join-Path $tiCache '*.xml') -Force -ErrorAction SilentlyContinue
            Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
        }
    })
}
# Registration happens once, after zoxide (below) has had a chance to enqueue its own init step.

#region UI Configuration
# Set window title
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion.ToString())"

# Set colors
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
#endregion

#region Environment Variables
# Add custom Scripts to PATH if not already there
$scriptsPath = Join-Path $HOME "Scripts"
if ((Test-Path $scriptsPath) -and ($env:Path -notlike "*$scriptsPath*")) {
    $env:Path = "$env:Path;$scriptsPath"
}

# Prepend local bin to PATH so user-installed tools shadow WinGet Links shims
$localBin = Join-Path $HOME ".local\bin"
if (Test-Path $localBin) {
    $env:Path = $env:Path -replace [regex]::Escape(";$localBin"), ''
    $env:Path = $env:Path -replace [regex]::Escape("$localBin;"), ''
    $env:Path = "$localBin;$env:Path"
}
if (-not $EDITOR) {
    $EDITOR = if (Get-Command code -ErrorAction SilentlyContinue) { 'code' }
          elseif (Get-Command codium -ErrorAction SilentlyContinue) { 'codium' }
          elseif (Get-Command notepad++ -ErrorAction SilentlyContinue) { 'notepad++' }
          else { 'notepad' }
    Set-Alias -Name vim -Value $EDITOR
}
#endregion

#region Aliases
# Navigation aliases
Set-Alias -Name ~ -Value Set-LocationHome -Option AllScope
function Set-LocationHome { Set-Location $HOME }

function pwdd { $("$PWD".replace($HOME, '~')) }

function Resolve-TildePath {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -eq '~') { return $HOME }
    if ($Path.StartsWith('~/') -or $Path.StartsWith('~\')) { return Join-Path $HOME $Path.Substring(2) }
    return $Path
}

function ln {
    # ln [-s] [-f] [-n] TARGET LINK_NAME (Linux argument order: target first, link name second)
    $symbolic = $false; $force = $false
    $paths = @(foreach ($a in $args) {
        if ($a -match '^-[a-zA-Z]+$') {
            if ($a -match 's') { $symbolic = $true }
            if ($a -match 'f') { $force = $true }
        } else { $a }
    })

    if ($paths.Count -ne 2) {
        Write-Error 'Usage: ln [-sfn] TARGET LINK_NAME'
        return
    }

    # New-Item's -Target does not go through PowerShell's path provider, so ~ never
    # expands there; leaving it literal made Windows unable to see the target was a
    # directory and it silently created a file symlink instead.
    $target = Resolve-TildePath $paths[0]
    $linkName = Resolve-TildePath $paths[1]

    if (-not $symbolic -and (Test-Path -LiteralPath $target -PathType Container)) {
        Write-Error 'ln: hard links to directories are not supported on Windows; use -s'
        return
    }

    # Get-Item -Force sees the link itself even when its target is missing/moved;
    # Test-Path dereferences first and under-reports broken links, so -f would
    # silently no-op instead of replacing them.
    $existing = Get-Item -LiteralPath $linkName -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if (-not $force) {
            Write-Error "ln: '$linkName' already exists (use -f to overwrite)"
            return
        }
        if ($existing.LinkType) {
            # It's a link/reparse point itself -- remove just the link, never -Recurse
            # into it, or a real directory it points at could get wiped instead.
            Remove-Item -LiteralPath $linkName -Force
        } else {
            Remove-Item -LiteralPath $linkName -Force -Recurse
        }
    }

    New-Item -ItemType $(if ($symbolic) { 'SymbolicLink' } else { 'HardLink' }) -Path $linkName -Target $target | Out-Null
}
# ls coloring
if (Get-Module -ListAvailable -Name PSColor) {
    Import-Module PSColor
    $global:PSColor = @{
        File = @{
            Default    = @{ Color = 'White' }
            Directory  = @{ Color = 'Blue'}
            Hidden     = @{ Color = 'DarkGray'; Pattern = '^\.'; }
            Code       = @{ Color = 'Magenta'; Pattern = '\.(java|c|cpp|cs|js|css|html)$' }
            Executable = @{ Color = 'Red'; Pattern = '\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$' }
            Text       = @{ Color = 'Yellow'; Pattern = '\.(txt|cfg|conf|ini|csv|log|config|xml|yml|md|markdown)$' }
            Compressed = @{ Color = 'Green'; Pattern = '\.(zip|tar|gz|rar|jar|war)$' }
        }
        Service = @{
            Default = @{ Color = 'White' }
            Running = @{ Color = 'DarkGreen' }
            Stopped = @{ Color = 'DarkRed' }
        }
        Match = @{
            Default    = @{ Color = 'White' }
            Path       = @{ Color = 'Cyan'}
            LineNumber = @{ Color = 'Yellow' }
            Line       = @{ Color = 'White' }
        }
        NoMatch = @{
            Default    = @{ Color = 'White' }
            Path       = @{ Color = 'Cyan'}
            LineNumber = @{ Color = 'Yellow' }
            Line       = @{ Color = 'White' }
        }
    }
}

# VCS aliases (git)
$vcsTools = @('git')
foreach ($cmd in $vcsTools) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $prefix = $cmd.Substring(0, 1)
        Set-Item -Path "Function:${prefix}s" -Value ([scriptblock]::Create("$cmd status `$args"))
        Set-Item -Path "Function:${prefix}a" -Value ([scriptblock]::Create("$cmd add `$args"))
        Set-Item -Path "Function:${prefix}c" -Value ([scriptblock]::Create("$cmd commit `$args"))
        Set-Item -Path "Function:${prefix}p" -Value ([scriptblock]::Create("$cmd push `$args"))
        Set-Item -Path "Function:${prefix}l" -Value ([scriptblock]::Create(`
            "$cmd log --oneline --graph --decorate `$args"))
        Set-Item -Path "Function:${prefix}d" -Value ([scriptblock]::Create("$cmd diff `$args"))
    }
}

# Docker aliases (if docker is installed)
if (Get-Command docker -ErrorAction SilentlyContinue) {
    function d { docker $args }
    function dc { docker-compose $args }
    function dps { docker ps $args }
    function dimg { docker images $args }
}
#endregion

#region Navigation Functions
# Easy navigation
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ..... { Set-Location ../../../.. }

# Common directories
function dotfiles { Set-Location -Path (Join-Path $env:USERPROFILE ".dotfiles\$args") }
function docs { Set-Location -Path ([Environment]::GetFolderPath('MyDocuments')) }
#endregion

#region Functions
function Get-DiskUsage {
    <#
    .SYNOPSIS
        Shows disk usage for all drives
    #>
    Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{
        Name = 'Used(GB)'; Expression = { [math]::Round($_.Used / 1GB, 2) }
    }, @{
        Name = 'Free(GB)'; Expression = { [math]::Round($_.Free / 1GB, 2) }
    }, @{
        Name = 'Total(GB)'; Expression = { [math]::Round(($_.Used + $_.Free) / 1GB, 2) }
    }, @{
        Name = 'Usage(%)'; Expression = {
            if (($_.Used + $_.Free) -gt 0) {
                [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 1)
            } else { 0 }
        }
    }
}
Set-Alias -Name df -Value Get-DiskUsage

function Get-FileSize {
    <#
    .SYNOPSIS
        Get human-readable file size
    .PARAMETER Path
        File path
    #>
    param([string]$Path = ".")

    Get-ChildItem -Path $Path -Recurse -File |
        Measure-Object -Property Length -Sum |
        Select-Object @{
            Name='Size';
            Expression={
                $size = $_.Sum
                if ($size -gt 1GB) { "{0:N2} GB" -f ($size / 1GB) }
                elseif ($size -gt 1MB) { "{0:N2} MB" -f ($size / 1MB) }
                elseif ($size -gt 1KB) { "{0:N2} KB" -f ($size / 1KB) }
                else { "{0:N2} bytes" -f $size }
            }
        }
}
Set-Alias -Name du -Value Get-FileSize

function Update-Profile {
    <#
    .SYNOPSIS
        Reload PowerShell profile
    #>
    if (Test-Path $PROFILE) {
        . $PROFILE
        Write-Host "Profile reloaded!" -ForegroundColor Green
    } else {
        Write-Warning "PowerShell profile not found."
    }
}
Set-Alias -Name sreload -Value Update-Profile

function Edit-Profile {
    <#
    .SYNOPSIS
        Edit PowerShell profile
    #>
    & $env:EDITOR (Join-Path $HOME ".dotfiles\config\powershell\Microsoft.PowerShell_profile.ps1")
}

function Get-PublicIP {
    <#
    .SYNOPSIS
        Get public IP address
    #>
    try {
        $ip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip
        Write-Host "Public IP: $ip" -ForegroundColor Cyan
        return $ip
    } catch {
        Write-Host "Failed to get public IP" -ForegroundColor Red
    }
}
Set-Alias -Name myip -Value Get-PublicIP

function touch {
    <#
    .SYNOPSIS
        Create new files or update timestamps, accepting pipeline input
    #>
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path
    )

    begin {
        [System.Collections.Generic.List[string]]$allPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($Path) {
            $allPaths.AddRange($Path)
        }
    }

    end {
        if ($allPaths -and $allPaths.Count -gt 0) {
            [array]$exists = Test-Path -LiteralPath $allPaths

            [System.Collections.Generic.List[string]]$existingPaths = [System.Collections.Generic.List[string]]::new()
            [System.Collections.Generic.List[string]]$newPaths = [System.Collections.Generic.List[string]]::new()

            for ($i = 0; $i -lt $allPaths.Count; $i++) {
                if ($exists[$i]) {
                    $existingPaths.Add($allPaths[$i])
                } else {
                    $newPaths.Add($allPaths[$i])
                }
            }

            if ($existingPaths.Count -gt 0) {
                $now = Get-Date
                Get-Item -LiteralPath $existingPaths | ForEach-Object {
                    $_.LastWriteTime = $now
                    Write-Warning "File $($_.FullName) already exists. Timestamp updated."
                }
            }

            foreach ($p in $newPaths) {
                [void](New-Item -ItemType File -Path $p)
                Write-Host "SUCCESS: File $p created." -ForegroundColor Green
            }
        }
    }
}

function mkcd {
    <#
    .SYNOPSIS
        Create directory and change into it, accepting pipeline input
    #>
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path
    )

    begin {
        [System.Collections.Generic.List[string]]$allPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($Path) {
            $allPaths.AddRange($Path)
        }
    }

    end {
        if ($allPaths -and $allPaths.Count -gt 0) {
            [array]$exists = Test-Path -LiteralPath $allPaths

            for ($i = 0; $i -lt $allPaths.Count; $i++) {
                $p = $allPaths[$i]
                if ($exists[$i]) {
                    Write-Warning "Directory $p already exists."
                } else {
                    [void](New-Item -ItemType Directory -Path $p -Force)
                }
            }
            # Change to the last path specified
            Set-Location $allPaths[-1]
        }
    }
}

# Open WinUtil full-release
function winutil {
  $temporaryFile = New-TemporaryFile
  $winutilInstaller = [System.IO.Path]::ChangeExtension($temporaryFile.FullName, '.ps1')
  Move-Item -LiteralPath $temporaryFile.FullName -Destination $winutilInstaller -Force

  try {
    Invoke-RestMethod -Uri 'https://christitus.com/win' -OutFile $winutilInstaller
    & $winutilInstaller
  } finally {
    if (Test-Path -LiteralPath $winutilInstaller) {
      Remove-Item -LiteralPath $winutilInstaller -Force
    }
  }
}

# Dev-channel companion to winutil
function winutildev {
  $temporaryFile = New-TemporaryFile
  $winutilInstaller = [System.IO.Path]::ChangeExtension($temporaryFile.FullName, '.ps1')
  Move-Item -LiteralPath $temporaryFile.FullName -Destination $winutilInstaller -Force

  try {
    Invoke-RestMethod -Uri 'https://christitus.com/windev' -OutFile $winutilInstaller
    & $winutilInstaller
  } finally {
    if (Test-Path -LiteralPath $winutilInstaller) {
      Remove-Item -LiteralPath $winutilInstaller -Force
    }
  }
}

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = @('pwsh.exe', '-NoExit', '-Command') + $args
        Start-Process wt -Verb runAs -ArgumentList $argList
    } else {
        Start-Process wt -Verb runAs
    }
}
Set-Alias -Name sudo -Value admin
Set-Alias -Name su -Value admin
function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}
# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }
# Recursive find-file-by-name
function ff { param($Name) Get-ChildItem -Recurse -Filter $Name -File | Select-Object -ExpandProperty FullName }


function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
          # Handle directory
            $parentPath = $item.Parent.FullName
        } else {
            # Handle file
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        } else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    } else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}
# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }
# Enhanced Listing
function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }
if (Get-Command eza -ErrorAction SilentlyContinue) {
    # ls is a built-in alias for Get-ChildItem; remove it so the function below takes over.
    Remove-Item -Path Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza -la @args }
}
# Git Shortcuts
function gs { git status }
function ga { git add -A }
function gc { param($m) git commit -m "$m" }
function gpush { git push }

function gpull { git pull }
function gcl { git clone "$args" }
function gcom {
    git add -A
    git commit -m "$args"
}
function lazyg {
    gcom @args
    git push
}
# Quick Access to System Information
function sysinfo { Get-ComputerInfo }
function uptime { (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime | Select-Object Days, Hours, Minutes, Seconds }

# Networking Utilities
function flushdns {
  Clear-DnsClientCache
  Write-Host "DNS has been flushed"
}
# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }

function Show-Help {
    <#
    .SYNOPSIS
        Lists the functions and aliases defined in this profile
    #>
    # $PSStyle is PowerShell 7.2+ only; fall back to no color under Windows PowerShell 5.1.
    $useColor = $PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 2 -or $PSVersionTable.PSVersion.Major -ge 8
    $title   = if ($useColor) { $PSStyle.Foreground.BrightMagenta } else { '' }
    $section = if ($useColor) { $PSStyle.Foreground.BrightBlue } else { '' }
    $command = if ($useColor) { $PSStyle.Foreground.BrightGreen } else { '' }
    $desc    = if ($useColor) { $PSStyle.Foreground.BrightWhite } else { '' }
    $accent  = if ($useColor) { $PSStyle.Foreground.BrightYellow } else { '' }
    $dim     = if ($useColor) { $PSStyle.Foreground.BrightBlack } else { '' }
    $reset   = if ($useColor) { $PSStyle.Reset } else { '' }

    Write-Host @"
${title}PowerShell Profile Help${reset}
${dim}------------------------------------------------------------${reset}

${section}Git shortcuts${reset}
  ${command}gs/ga/gc/gpush/gpull/gd/gl${reset} ${accent}->${reset} ${desc}status/add/commit/push/pull/diff/log (per VCS prefix)${reset}
  ${command}gcom <message>${reset}      ${accent}->${reset} ${desc}add + commit${reset}
  ${command}lazyg <message>${reset}     ${accent}->${reset} ${desc}add + commit + push${reset}

${section}Navigation${reset}
  ${command}docs${reset}                ${accent}->${reset} ${desc}Documents folder${reset}
  ${command}dotfiles${reset}            ${accent}->${reset} ${desc}~/.dotfiles${reset}
  ${command}.. / ... / ....${reset}     ${accent}->${reset} ${desc}up N directories${reset}

${section}Files${reset}
  ${command}ff <name>${reset}           ${accent}->${reset} ${desc}find file recursively${reset}
  ${command}nf <name>${reset}           ${accent}->${reset} ${desc}new file${reset}
  ${command}touch <path>${reset}        ${accent}->${reset} ${desc}create/update timestamp${reset}
  ${command}mkcd <dir>${reset}          ${accent}->${reset} ${desc}create + enter dir${reset}
  ${command}trash <path>${reset}        ${accent}->${reset} ${desc}move to Recycle Bin${reset}
  ${command}la / ll${reset}             ${accent}->${reset} ${desc}list files${reset}
  ${command}du / df${reset}             ${accent}->${reset} ${desc}file size / disk usage${reset}

${section}System${reset}
  ${command}sysinfo${reset}             ${accent}->${reset} ${desc}Get-ComputerInfo${reset}
  ${command}uptime${reset}              ${accent}->${reset} ${desc}system uptime${reset}
  ${command}flushdns${reset}            ${accent}->${reset} ${desc}clear DNS cache${reset}
  ${command}myip${reset}                ${accent}->${reset} ${desc}public IP address${reset}
  ${command}winutil / winutildev${reset} ${accent}->${reset} ${desc}run WinUtil (stable / dev)${reset}
  ${command}Clear-TempFile${reset}      ${accent}->${reset} ${desc}clear temp files${reset}
  ${command}supdate / pupdate${reset}   ${accent}->${reset} ${desc}update PowerShell tools / all winget packages${reset}

${section}Misc${reset}
  ${command}which <name>${reset}        ${accent}->${reset} ${desc}locate command${reset}
  ${command}grep <pattern> [dir]${reset} ${accent}->${reset} ${desc}search text${reset}
  ${command}sed <file> <find> <replace>${reset} ${accent}->${reset} ${desc}replace text${reset}
  ${command}pgrep/pkill/k9 <name>${reset} ${accent}->${reset} ${desc}find/stop process${reset}
  ${command}export <name> <value>${reset} ${accent}->${reset} ${desc}set env var${reset}
  ${command}sreload${reset}             ${accent}->${reset} ${desc}reload this profile${reset}
  ${command}Edit-Profile${reset}        ${accent}->${reset} ${desc}open this profile in \$EDITOR${reset}

${dim}------------------------------------------------------------${reset}
"@
}

# PSReadLine Configuration (single consolidated block; see #region below for key handlers)
if (Get-Module -ListAvailable -Name PSReadLine) {
    $PSReadLineOptions = @{
        EditMode                     = 'Windows'
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        BellStyle                     = 'None'
    }
    Set-PSReadLineOption @PSReadLineOptions
    # ListView prediction requires a VT-capable console; falls back to plain history prediction
    # under redirected output or non-VT hosts (CI, some remoting sessions).
    # Any non-default PredictionSource requires a VT-capable, non-redirected console;
    # setting one under redirected output (CI, some remoting/agent shells) throws.
    if ($Host.UI.SupportsVirtualTerminal -and -not [System.Console]::IsOutputRedirected) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView -MaximumHistoryCount 10000
        } else {
            Set-PSReadLineOption -PredictionSource History
        }
    }
    Set-PSReadLineOption -Colors @{
        Command   = 'Cyan'
        Parameter = 'Gray'
        Operator  = 'White'
        Variable  = 'Green'
        String    = 'Yellow'
        Number    = 'Magenta'
        Type      = 'DarkCyan'
        Comment   = 'DarkGray'
    }
    # Custom key handlers
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo
    # Allow local.ps1 to override prediction settings
    if (Get-Command -Name 'Set-PredictionSource_Override' -ErrorAction SilentlyContinue) {
        Set-PredictionSource_Override
    }
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $__initQueue.Enqueue({ . ([scriptblock]::Create((zoxide init --cmd z powershell | Out-String))) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        $__initQueue.Enqueue({ . ([scriptblock]::Create((zoxide init --cmd z powershell | Out-String))) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}
if ($__initQueue.Count -gt 0) {
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
        if ($__initQueue.Count -gt 0) {
            & $__initQueue.Dequeue()
        }
        else {
            Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
            Remove-Variable -Name '__initQueue' -Scope Global -Force
        }
    } | Out-Null
}

function Get-CommandPath {
    <#
    .SYNOPSIS
        Get full path of a command (like Unix 'which')
    #>
    param([Parameter(Mandatory)][string]$Command)

    (Get-Command $Command -ErrorAction SilentlyContinue).Source
}

function Clear-TempFile {
    <#
    .SYNOPSIS
        Clear temporary files
    #>
    $tempPaths = @(
        (Join-Path $env:TEMP "*"),
        (Join-Path $env:WINDIR "Temp\*")
    )

    foreach ($path in $tempPaths) {
        Write-Host "Cleaning $path..." -ForegroundColor Yellow
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Temp files cleared!" -ForegroundColor Green
}

# Update PowerShell and related tools
function supdate {
    $packages = @(
        "Microsoft.Powershell",
        "chrisant996.Clink",
        "Starship.Starship"
    )

    foreach ($package in $packages) {
        Write-Host "Upgrading $package..." -ForegroundColor Cyan
        [void](winget upgrade --id $package `
            --silent --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$package upgraded" -ForegroundColor Green
        }
    }
}

# Update all winget packages
function pupdate {
    Write-Host "Upgrading all packages..." -ForegroundColor Cyan
    winget upgrade --all --accept-source-agreements --accept-package-agreements --disable-interactivity
}
#endregion

#region Chocolatey Profile
# Import Chocolatey Profile to enable tab-completions
$ChocolateyProfile = Join-Path $env:ChocolateyInstall "helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
#endregion

# Prompt is provided by oh-my-posh, initialized asynchronously via $__initQueue above.

#region Startup Message
# Minimal startup for faster loading
#endregion

# Load any local customizations (not tracked in git)
$localProfile = Join-Path $HOME ".dotfiles\config\powershell\local.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}
