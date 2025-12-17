# PowerShell Profile
# Location: $HOME\.dotfiles\config\powershell\profile.ps1
# Managed by yadm

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
$scriptsPath = "$HOME\Scripts"
if ((Test-Path $scriptsPath) -and ($env:Path -notlike "*$scriptsPath*")) {
    $env:Path = "$env:Path;$scriptsPath"
}

# Add local bin to PATH
$localBin = "$HOME\.local\bin"
if ((Test-Path $localBin) -and ($env:Path -notlike "*$localBin*")) {
    $env:Path = "$env:Path;$localBin"
}

# Set default editor
if (Get-Command code -ErrorAction SilentlyContinue) {
    $env:EDITOR = "code"
} elseif (Get-Command vim -ErrorAction SilentlyContinue) {
    $env:EDITOR = "vim"
} else {
    $env:EDITOR = "notepad"
}
#endregion

#region Aliases
# Navigation aliases
Set-Alias -Name ~ -Value Set-LocationHome -Option AllScope
function Set-LocationHome { Set-Location $HOME }

# Common commands
Set-Alias -Name which -Value Get-Command
Set-Alias -Name grep -Value Select-String

# Git aliases (if git is installed)
if (Get-Command git -ErrorAction SilentlyContinue) {
    function gs { git status $args }
    function ga { git add $args }
    function gc { git commit $args }
    function gp { git push $args }
    function gl { git log --oneline --graph --decorate $args }
    function gd { git diff $args }
}

# yadm aliases
if (Get-Command yadm -ErrorAction SilentlyContinue) {
    function ys { yadm status $args }
    function ya { yadm add $args }
    function yc { yadm commit $args }
    function yp { yadm push $args }
    function yl { yadm log --oneline --graph --decorate $args }
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
function dotfiles { Set-Location -Path "$env:USERPROFILE\.dotfiles\$args" }
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
    & $env:EDITOR "$HOME\.dotfiles\config\powershell\profile.ps1"
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
        Create a new file or update timestamp
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
        Write-Warning "File $Path already exists. Timestamp updated."
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
        Write-Host "SUCCESS: File $Path created." -ForegroundColor Green
    }
}

function mkcd {
    <#
    .SYNOPSIS
        Create directory and change into it
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path $Path) {
        Write-Warning "Directory $Path already exists."
    } else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    Set-Location $Path
}

function Get-CommandPath {
    <#
    .SYNOPSIS
        Get full path of a command (like Unix 'which')
    #>
    param([Parameter(Mandatory)][string]$Command)

    (Get-Command $Command -ErrorAction SilentlyContinue).Source
}

function Clear-TempFiles {
    <#
    .SYNOPSIS
        Clear temporary files
    #>
    $tempPaths = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*"
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
        winget upgrade --id $package --silent --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $package upgraded" -ForegroundColor Green
        }
    }
}

# Update all winget packages
function pupdate {
    Write-Host "Upgrading all packages..." -ForegroundColor Cyan
    winget upgrade --all --accept-source-agreements --accept-package-agreements --disable-interactivity
}
#endregion

#region PSReadLine Configuration
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    # Set edit mode to Emacs (or Vi if you prefer)
    Set-PSReadLineOption -EditMode Emacs

    # History configuration
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Tab completion
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Prediction
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    # Colors
    Set-PSReadLineOption -Colors @{
        Command = 'Cyan'
        Parameter = 'Gray'
        Operator = 'White'
        Variable = 'Green'
        String = 'Yellow'
        Number = 'Magenta'
        Type = 'DarkCyan'
        Comment = 'DarkGray'
    }
}
#endregion

#region Chocolatey Profile
# Import Chocolatey Profile to enable tab-completions
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
#endregion

#region Prompt
# Starship PreCommand Hook
function Invoke-Starship-PreCommand {
    $host.ui.RawUI.WindowTitle = (Get-Item $pwd).Name
}

# Initialize Starship prompt (if available)
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
} else {
    # Fallback to custom prompt if Starship is not installed
    function prompt {
        $location = Get-Location
        $drive = Split-Path -Qualifier $location
        $path = Split-Path -NoQualifier $location

        # Shorten path if too long
        if ($path.Length -gt 30) {
            $pathParts = $path.Split('\')
            if ($pathParts.Count -gt 3) {
                $path = "\..\$($pathParts[-2])\$($pathParts[-1])"
            }
        }

        # Git branch (if in a git repo)
        $gitBranch = ""
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $branch = git branch --show-current 2>$null
            if ($branch) {
                $gitBranch = " [$branch]"
            }
        }

        # Build prompt
        Write-Host "$drive$path" -NoNewline -ForegroundColor Cyan
        if ($gitBranch) {
            Write-Host $gitBranch -NoNewline -ForegroundColor Yellow
        }

        return "> "
    }
}
#endregion

#region Startup Message
# Minimal startup for faster loading
#endregion

# Load any local customizations (not tracked by yadm)
$localProfile = "$HOME\.dotfiles\config\powershell\local.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}
