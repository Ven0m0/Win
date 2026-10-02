## PowerShell Profile
# Location: $HOME\.dotfiles\config\powershell\Microsoft.PowerShell_profile.ps1
# Managed by dotbot

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true' `
        , [System.EnvironmentVariableTarget]::Machine)
}

$ProgressPreference = 'SilentlyContinue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'
$env:VCPKG_DISABLE_METRICS = 'true'
$env:RTK_HOOK_AUDIT = '1'

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
# PSCompletions: tab-completion for many CLIs. Enable per tool once with `psc add <name>`.
if (Get-Module -ListAvailable -Name PSCompletions) {
    $__initQueue.Enqueue({ Import-Module -Name PSCompletions -ErrorAction SilentlyContinue })
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
# Activate default Python venv (deferred: Activate.ps1 scopes its prompt/env
# changes with global:, so dot-sourcing it from the async queue still works).
#$__initQueue.Enqueue({
#    $defaultVenv = "$env:USERPROFILE\.venv\Scripts\Activate.ps1"
#    if (Test-Path $defaultVenv) {
#        . $defaultVenv
#    }
#})
$defaultVenv = "$env:USERPROFILE\.venv\Scripts\Activate.ps1"
if (Test-Path $defaultVenv) {
  $null = . "$env:USERPROFILE\.venv\Scripts\Activate.ps1"
}

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
    # Deferred: the Get-Command probes below scan $env:Path each time and
    # aren't needed before the prompt renders.
    $__initQueue.Enqueue({
        $Script:EDITOR = if (Get-Command fresh -ErrorAction SilentlyContinue) { 'fresh' }
              elseif (Get-Command notepad++ -ErrorAction SilentlyContinue) { 'notepad++' }
              elseif (Get-Command codium -ErrorAction SilentlyContinue) { 'codium' }
              else { 'notepad' }
    })
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
# ls coloring (deferred: Import-Module + hashtable build isn't needed before the prompt renders)
$__initQueue.Enqueue({
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
})
#endregion

#region Navigation Functions
# Easy navigation
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ..... { Set-Location ../../../.. }
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
function Invoke-WinUtil {
  param([string]$Uri = 'https://christitus.com/win')

  $temporaryFile = New-TemporaryFile
  $winutilInstaller = [System.IO.Path]::ChangeExtension($temporaryFile.FullName, '.ps1')
  Move-Item -LiteralPath $temporaryFile.FullName -Destination $winutilInstaller -Force

  try {
    Invoke-RestMethod -Uri $Uri -OutFile $winutilInstaller
    & $winutilInstaller
  } finally {
    if (Test-Path -LiteralPath $winutilInstaller) {
      Remove-Item -LiteralPath $winutilInstaller -Force
    }
  }
}
function winutil { Invoke-WinUtil }
# Dev-channel companion to winutil
function winutildev { Invoke-WinUtil -Uri 'https://christitus.com/windev' }

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

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }
# Enhanced Listing
function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }
if (Get-Command eza -ErrorAction SilentlyContinue) {
    # ls is a built-in alias for Get-ChildItem; remove it so the function below takes over.
    Remove-Item -Path Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza -la --group-directories-first --no-git @args }
}
# Git Shortcuts
function gs { git status }
function ga { git add -A }
# gc is a built-in alias for Get-Content; remove it so the function below takes over.
Remove-Item -Path Alias:gc -Force -ErrorAction SilentlyContinue
function gc { param($m) git commit -m "$m" }
function gpush { git push }
function gpull { git pull }
function gd { git diff @args }
# gl is a built-in alias for Get-Location; remove it so the function below takes over.
Remove-Item -Path Alias:gl -Force -ErrorAction SilentlyContinue
function gl { git log --oneline --graph --decorate @args }
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
  ${command}.. / ... / ....${reset}     ${accent}->${reset} ${desc}up N directories${reset}

${section}Files${reset}
  ${command}touch <path>${reset}        ${accent}->${reset} ${desc}create/update timestamp${reset}
  ${command}mkcd <dir>${reset}          ${accent}->${reset} ${desc}create + enter dir${reset}
  ${command}la / ll${reset}             ${accent}->${reset} ${desc}list files${reset}
  ${command}du / df${reset}             ${accent}->${reset} ${desc}file size / disk usage${reset}

${section}System${reset}
  ${command}sysinfo${reset}             ${accent}->${reset} ${desc}Get-ComputerInfo${reset}
  ${command}uptime${reset}              ${accent}->${reset} ${desc}system uptime${reset}
  ${command}flushdns${reset}            ${accent}->${reset} ${desc}clear DNS cache${reset}
  ${command}myip${reset}                ${accent}->${reset} ${desc}public IP address${reset}
  ${command}winutil / winutildev${reset} ${accent}->${reset} ${desc}run WinUtil (stable / dev)${reset}
  ${command}Clear-TempFile${reset}      ${accent}->${reset} ${desc}clear temp files${reset}

${section}Misc${reset}
  ${command}which <name>${reset}        ${accent}->${reset} ${desc}locate command${reset}
  ${command}grep <pattern> [dir]${reset} ${accent}->${reset} ${desc}search text${reset}
  ${command}sed <file> <find> <replace>${reset} ${accent}->${reset} ${desc}replace text${reset}
  ${command}pgrep/pkill/k9 <name>${reset} ${accent}->${reset} ${desc}find/stop process${reset}
  ${command}export <name> <value>${reset} ${accent}->${reset} ${desc}set env var${reset}

${dim}------------------------------------------------------------${reset}
"@
}

# PSReadLine Configuration (single consolidated block; see #region below for key handlers)
# PSReadLine ships built into the PowerShell host and is already imported into the session
# by the time the profile runs, so checking the loaded-module list (no -ListAvailable disk
# scan of $env:PSModulePath) is enough to guard these calls.
if (Get-Module -Name PSReadLine) {
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
    Write-Warning "zoxide not found. Install with: winget install -e --id ajeetdsouza.zoxide"
}
if ($__initQueue.Count -gt 0) {
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
        if ($__initQueue.Count -gt 0) {
            # Dot-source, not `&`: steps must run in global scope like normal profile code.
            # PSCompletions creates $PSCompletions in the importing scope; in a child scope
            # it vanishes after the step and its Tab handler then fails on a null variable.
            . $__initQueue.Dequeue()
        }
        else {
            Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
            Remove-Variable -Name '__initQueue' -Scope Global -Force
        }
    } | Out-Null
}
#endregion

#region Chocolatey Profile
# Import Chocolatey Profile to enable tab-completions (deferred: tab-completion
# registration isn't needed before the prompt renders)
$__initQueue.Enqueue({
    if ($env:ChocolateyInstall) {
        $ChocolateyProfile = Join-Path $env:ChocolateyInstall "helpers\chocolateyProfile.psm1"
        if (Test-Path $ChocolateyProfile) {
            Import-Module $ChocolateyProfile
        }
    }
})
#endregion

# DO NOT MODIFY -- coreutils -- 60b36fc6-2d59-49df-be51-28dd2f4c3c9a
# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Inlining the template into the profile shaves off ~10ms (25%).
$script:__COREUTILS__ = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('arch','b2sum','base32','base64','basename','basenc','cat','cksum','comm','cp','csplit','cut','date','df','dirname','du','echo','env','expr','factor','false','find','fmt','fold','grep','head','hostname','join','la','link','ln','ls','md5sum','mkdir','mktemp','mv','nl','nproc','numfmt','od','paste','pathchk','pr','printenv','printf','ptx','pwd','readlink','realpath','rm','rmdir','seq','sha1sum','sha224sum','sha256sum','sha384sum','sha512sum','shuf','sleep','sort','split','stat','sum','tac','tail','tee','test','touch','tr','true','truncate','tsort','unexpand','uniq','unlink','uptime','wc','xargs','yes'),
    [System.StringComparer]::OrdinalIgnoreCase
)

$script:__COREUTILS_FAST_SKIP__ = [regex]::new(
    '\b(?:' + ($script:__COREUTILS__ -join '|') + ')\b',
    [System.Text.RegularExpressions.RegexOptions]::Compiled -bor `
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

# Casting the scriptblock to Func<Ast,bool> once and reusing it avoids the
# per-FindAll scriptblock-to-delegate wrapping overhead (~1.7x faster).
$script:__COREUTILS_CMD_PREDICATE__ = [System.Func[System.Management.Automation.Language.Ast, bool]] {
    param($n) $n -is [System.Management.Automation.Language.CommandAst]
}

$script:__COREUTILS_ARG_SPECIAL__ = [char[]] @("'", '"', '`', '$')

# Wrap arguments into quotes. By being a function we can properly handle $variables.
# As per MSVCRT, any `\` before `"` must be doubled to escape them.
function global:__coreutils_q {
    param($s)
    '"' + (([string]$s) -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

# PowerShell tokenizes `*"a"*` as [BareWord] instead of the expected [DoubleQuoted, BareWord, DoubleQuoted].
# To work around that we use... regex. Group 1 = 'single', 2 = "double", 3 = `escape, 4 = bare run.
$script:__COREUTILS_ARG_RX__ = [regex]::new(
    "'((?:[^']|'')*)'|""((?:[^""``]|""""|``.)*)""|``(.)|([^'""``]+)",
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)
$script:__COREUTILS_ARG_EVAL__ = [System.Text.RegularExpressions.MatchEvaluator] {
    param($m)
    if ($m.Groups[1].Success) {
        # Single-quoted: literal. PS '' -> ', then MSVCRT-quote.
        $body = $m.Groups[1].Value.Replace("''", "'")
        if ($body -match '^(.*?)(\\+)$') {
            return '"' + ($matches[1] -replace '(\\*)"', '$1$1\"') + '"' + $matches[2]
        }
        return '"' + ($body -replace '(\\*)"', '$1$1\"') + '"'
    }
    if ($m.Groups[2].Success) {
        # Double-quoted: collapse PS quote-escapes to raw " / ', let ExpandString
        # resolve `n / `t / $var, then MSVCRT-quote.
        $body = $m.Groups[2].Value.
        Replace('`"', '"').
        Replace("``'", "'").
        Replace('""', '"')
        $body = $ExecutionContext.InvokeCommand.ExpandString($body)
        if ($body -match '^(.*?)(\\+)$') {
            return '"' + ($matches[1] -replace '(\\*)"', '$1$1\"') + '"' + $matches[2]
        }
        return '"' + ($body -replace '(\\*)"', '$1$1\"') + '"'
    }
    if ($m.Groups[3].Success) {
        # Backtick-escaped char outside a string: " -> \"; everything else
        # becomes a one-char quoted region so glob metas stay literal.
        $c = $m.Groups[3].Value
        if ($c -eq '"') {
            return '\"'
        }
        return '"' + $c + '"'
    }
    # Bare run: passed through unquoted so coreutils can glob it; expand $vars.
    return $ExecutionContext.InvokeCommand.ExpandString($m.Groups[4].Value)
}

# 0: not tested, 1: coreutils not installed, 2: coreutils installed.
$script:__COREUTILS_CMD_DIR_TEST__ = 0

# PSConsoleHostReadLine override that rewrites coreutils command names to their
# .cmd equivalents after PSReadLine returns (history keeps the original).
#
# Why .cmd over .exe: PSNativeCommandArgumentPassing = 'Windows' results in a behavior
# where passing bare quotes to CreateProcess() is impossible. This prevents us from
# passing "*" as "*" to coreutils and instead will be given as a bare *.
# This causes it to treat it as a glob pattern. "*.cmd" files however are automatically
# treated as PSNativeCommandArgumentPassing = 'Legacy', which preserves quotes.
# It is the only possible workaround and the only way coreutils can work at all.
function PSConsoleHostReadLine {
    [System.Diagnostics.DebuggerHidden()]
    param()

    $lastRunStatus = $?
    Microsoft.PowerShell.Core\Set-StrictMode -Off
    $line = [Microsoft.PowerShell.PSConsoleReadLine]::ReadLine($host.Runspace, $ExecutionContext, $lastRunStatus)

    # If the line contains no coreutils name, we don't need to parse the AST at all.
    if (-not $script:__COREUTILS_FAST_SKIP__.IsMatch($line)) {
        return $line
    }

    # Roamed/synced profiles can load this snippet on machines where coreutils is not installed.
    # Test for the existence of the command directory once and remember the result.
    if ($script:__COREUTILS_CMD_DIR_TEST__ -eq 0) {
        $script:__COREUTILS_CMD_DIR_TEST__ = 1
        if (Test-Path -LiteralPath 'C:\Program Files\coreutils\cmd\' -PathType Container -ErrorAction Ignore) {
            $script:__COREUTILS_CMD_DIR_TEST__ = 2
        }
    }
    if ($script:__COREUTILS_CMD_DIR_TEST__ -ne 2) {
        return $line
    }

    $ast = [System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$null, [ref]$null)
    $commands = $ast.FindAll($script:__COREUTILS_CMD_PREDICATE__, $true)

    # Process right-to-left so earlier offsets stay valid after each splice.
    # In-place reverse beats Sort-Object for the typical 1-command line.
    if ($commands.Count -gt 1) {
        $commands = [System.Collections.Generic.List[object]]::new($commands)
        $commands.Reverse()
    }

    foreach ($cmd in $commands) {
        $name = $cmd.GetCommandName()
        if (!$name) {
            continue
        }

        $baseName = $name
        if ($name.EndsWith('.exe') -or $name.EndsWith('.cmd')) {
            $baseName = $name.Substring(0, $name.Length - 4)
        }
        if (!$script:__COREUTILS__.Contains($baseName)) {
            continue
        }

        # ls/la get colour + listing flags injected; la also rewrites to ls.
        $cmdElement = $cmd.CommandElements[0]
        $start = $cmdElement.Extent.StartOffset
        $end = $cmdElement.Extent.EndOffset
        $replacement = "& 'C:\Program Files\coreutils\cmd\"

        switch ($baseName) {
            'la' { $replacement += "ls.cmd' --color=auto -AFhl" }
            'ls' { $replacement += "ls.cmd' --color=auto" }
            default { $replacement += "$baseName.cmd'" }
        }

        # Walk command elements, merging adjacent ones whose extents touch
        # (e.g. `'a'*` parses as [SingleQuoted, BareWord] but is one shell word).
        # The inverse case `*'a'*` parses as a single BareWord whose text
        # contains the embedded quotes, which is why AST-only analysis
        # isn't enough and we still need to re-tokenize the source span.
        $argsStart = $end
        $argsEnd = $cmd.Extent.EndOffset
        $rewrittenArgs = ''
        $elements = $cmd.CommandElements
        $count = $elements.Count
        $i = 1
        while ($i -lt $count) {
            $first = $elements[$i]
            $wordStart = $first.Extent.StartOffset
            $wordEnd = $first.Extent.EndOffset
            $merged = $false
            while ($i + 1 -lt $count -and $elements[$i + 1].Extent.StartOffset -eq $wordEnd) {
                $i++
                $wordEnd = $elements[$i].Extent.EndOffset
                $merged = $true
            }
            $source = $line.Substring($wordStart, $wordEnd - $wordStart)
            $rewrittenArgs += $line.Substring($argsStart, $wordStart - $argsStart)
            $argsStart = $wordEnd
            # IndexOfAny beats running the regex per arg.
            if ($source.IndexOfAny($script:__COREUTILS_ARG_SPECIAL__) -lt 0) {
                $rewrittenArgs += $source
                $i++
                continue
            }
            # A single un-merged PS expression that needs $var resolution
            # (bare $var, "...$var...", $x.Member, $($expr), etc.).
            # Defer evaluation to runtime so the value reaches coreutils as a literal arg.
            # This matches POSIX behaviour where variable expansions don't result in globbing.
            if (-not $merged -and
                ($first -is [System.Management.Automation.Language.VariableExpressionAst] -or
                $first -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -or
                $first -is [System.Management.Automation.Language.MemberExpressionAst])) {
                $rewrittenArgs += '(__coreutils_q ' + $source + ')'
                $i++
                continue
            }
            # Slow path: re-tokenise and re-emit as MSVCRT-style quoting,
            # then wrap in PS single quotes so PS hands the body verbatim.
            $windowsQuoted = $script:__COREUTILS_ARG_RX__.Replace($source, $script:__COREUTILS_ARG_EVAL__)
            $rewrittenArgs += "'" + $windowsQuoted.Replace("'", "''") + "'"
            $i++
        }
        $rewrittenArgs += $line.Substring($argsStart, $argsEnd - $argsStart)

        $line = $line.Substring(0, $start) + $replacement + $rewrittenArgs + $line.Substring($argsEnd)
    }

    return $line
}
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# DO NOT MODIFY -- coreutils -- 60b36fc6-2d59-49df-be51-28dd2f4c3c9a
