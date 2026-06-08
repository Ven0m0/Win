#Requires -Version 5.1
# Requires Administrator privileges
# This script enables global timer resolution and sets up a scheduled task to persist the timer resolution on logon

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Import shared helpers
. "$PSScriptRoot\Common.ps1"

# Configuration
$ExePath = "$env:SystemDrive\SetTimerResolution.exe"
$DownloadUrl = "https://github.com/valleyofdoom/TimerResolution/releases/download/" + `
  "SetTimerResolution-v1.0.0/SetTimerResolution.exe"
$TaskName = "SetTimerResolution-AutoStart"
$Resolution = 5040  # fallback default (0.504ms); overridden by Select-OptimalResolution at runtime
$ResolutionMinHns = 5000  # 0.5ms in 100ns units
$ResolutionMaxHns = 6000  # 0.6ms in 100ns units

# P/Invoke bindings for NtDll timer resolution API
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class NtTimer {
    [DllImport("ntdll.dll")]
    public static extern int NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);
    [DllImport("ntdll.dll")]
    public static extern int NtQueryTimerResolution(out uint MinimumResolution, out uint MaximumResolution, out uint CurrentResolution);
}
'@

# Function to write colored messages
function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Status = "Info"  # Info, Success, Warning, Error
    )
    $colors = @{
        "Info"    = 'White'
        "Success" = 'Green'
        "Warning" = 'Yellow'
        "Error"   = 'Red'
    }
    $prefix = @{
        "Info"    = "[INFO]"
        "Success" = "[OK]"
        "Warning" = "[WARN]"
        "Error"   = "[ERROR]"
    }
    Write-Host "$($prefix[$Status]) $Message" -ForegroundColor $colors[$Status]
}

# Measures sleep accuracy for a given timer resolution (in 100ns units).
# Returns a PSCustomObject with Resolution, MeanMs, StdDevMs, and Score (lower = better).
function Measure-TimerResolutionAccuracy {
    param(
        [uint32]$Resolution,
        [int]$Samples = 50
    )
    $current = [uint32]0
    $null = [NtTimer]::NtSetTimerResolution($Resolution, $true, [ref]$current)
    Start-Sleep -Milliseconds 15  # allow resolution to stabilize

    $measurements = [System.Collections.Generic.List[double]]::new()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $Samples; $i++) {
        $sw.Restart()
        [System.Threading.Thread]::Sleep(1)
        $sw.Stop()
        $measurements.Add($sw.Elapsed.TotalMilliseconds)
    }

    $null = [NtTimer]::NtSetTimerResolution($Resolution, $false, [ref]$current)

    $mean = ($measurements | Measure-Object -Average).Average
    $variance = ($measurements | ForEach-Object { [Math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average
    $stdDev = [Math]::Sqrt($variance)
    $score = [Math]::Abs($mean - 1.0) + $stdDev

    return [PSCustomObject]@{
        Resolution   = $Resolution
        ResolutionMs = [Math]::Round($Resolution / 10000.0, 4)
        MeanMs       = [Math]::Round($mean, 4)
        StdDevMs     = [Math]::Round($stdDev, 4)
        Score        = [Math]::Round($score, 6)
    }
}

# Tests all resolution values in [$MinHns..$MaxHns] with $Step increments and returns
# the uint32 value with the lowest sleep-accuracy score.
function Select-OptimalResolution {
    param(
        [uint32]$MinHns  = $ResolutionMinHns,
        [uint32]$MaxHns  = $ResolutionMaxHns,
        [uint32]$Step    = 100
    )
    Write-StatusMessage "Measuring sleep accuracy across $(($MaxHns - $MinHns) / $Step + 1) resolution values ($($MinHns/10000.0)ms - $($MaxHns/10000.0)ms)..." "Info"

    $results = [System.Collections.Generic.List[object]]::new()
    $value = $MinHns
    while ($value -le $MaxHns) {
        $r = Measure-TimerResolutionAccuracy -Resolution $value
        Write-StatusMessage ("  {0,6} ({1}ms)  mean={2}ms  stddev={3}ms  score={4}" -f `
            $r.Resolution, $r.ResolutionMs, $r.MeanMs, $r.StdDevMs, $r.Score) "Info"
        $results.Add($r)
        $value += $Step
    }

    $best = $results | Sort-Object Score | Select-Object -First 1
    Write-StatusMessage ("Optimal resolution: {0} ({1}ms)  mean={2}ms  stddev={3}ms" -f `
        $best.Resolution, $best.ResolutionMs, $best.MeanMs, $best.StdDevMs) "Success"
    return [uint32]$best.Resolution
}

# Function to download SetTimerResolution.exe
function Get-TimerResolutionExe {
    Write-StatusMessage "Checking for SetTimerResolution.exe at $ExePath..." "Info"
    if (Test-Path $ExePath) {
        Write-StatusMessage "SetTimerResolution.exe already exists at $ExePath" "Success"
        return $true
    }

    Write-StatusMessage "SetTimerResolution.exe not found. Downloading from GitHub..." "Warning"
    try {
        Get-FileFromWeb -URL $DownloadUrl -File $ExePath
        if (Test-Path $ExePath) {
            Write-StatusMessage "SetTimerResolution.exe downloaded successfully to $ExePath" "Success"
            return $true
        } else {
            throw "Download completed but file not found"
        }
    } catch {
        Write-StatusMessage "Failed to download SetTimerResolution.exe: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Function to setup scheduled task
function Set-TimerResolutionTask {
    param([switch]$Force = $false)
    
    Write-StatusMessage "Checking for scheduled task '$TaskName'..." "Info"
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if ($existingTask -and -not $Force) {
        Write-StatusMessage "Scheduled task '$TaskName' already exists, skipping creation" "Success"
        return $true
    }
    
    if ($existingTask -and $Force) {
        Write-StatusMessage "Removing existing task for reconfiguration..." "Info"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    Write-StatusMessage "Creating scheduled task '$TaskName'..." "Info"
    
    try {
        $action = New-ScheduledTaskAction -Execute $ExePath -Argument "--resolution $Resolution --no-console"
        
        # Create trigger: at logon, for any user
        $trigger = New-ScheduledTaskTrigger -AtLogon
        
        # Create settings: allow start on demand, run whether user is logged on or not
        $settings = New-ScheduledTaskSettingsSet `
          -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        # Create principal: run with highest privileges
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # Register the task
        $null = Register-ScheduledTask -TaskName $TaskName -Action $action `
          -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop
        
        Write-StatusMessage "Scheduled task '$TaskName' created successfully" "Success"
        Write-StatusMessage "Task will run at: At Logon" "Info"
        Write-StatusMessage ("Timer resolution: {0}ms ({1} * 100ns)" -f ($Resolution / 10000.0), $Resolution) "Info"
        Write-StatusMessage "Executable path: $ExePath" "Info"
        
        return $true
    } catch {
        Write-StatusMessage "Failed to create scheduled task: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Function to start timer resolution immediately
function Start-TimerResolutionNow {
    Write-StatusMessage "Starting timer resolution now..." "Info"
    
    # Try via scheduled task first
    try {
        $taskInfo = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        if ($taskInfo.State -eq "Running") {
            Write-StatusMessage "Task is already running" "Success"
            return $true
        }
        Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Start-Sleep -Seconds 1
        $taskInfo = Get-ScheduledTask -TaskName $TaskName
        if ($taskInfo.State -eq "Running") {
            Write-StatusMessage "Task started via Task Scheduler (State: Running)" "Success"
            return $true
        }
    } catch {
        Write-StatusMessage "Could not start via Task Scheduler, trying direct execution..." "Warning"
    }
    
    # Fall back to direct execution
    try {
        $runningProcess = Get-Process -Name "SetTimerResolution" -ErrorAction SilentlyContinue
        if ($runningProcess) {
            Write-StatusMessage "SetTimerResolution already running (PID: $($runningProcess.Id))" "Success"
            return $true
        }
        
        $process = Start-Process -FilePath $ExePath `
          -ArgumentList "--resolution $Resolution --no-console" -WindowStyle Hidden -PassThru
        Write-StatusMessage "SetTimerResolution started directly (PID: $($process.Id))" "Success"
        return $true
    } catch {
        Write-StatusMessage "Failed to start SetTimerResolution: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Function to check current status
function Get-TimerResolutionStatus {
    Write-StatusMessage "" "Info"
    Write-StatusMessage "=== Timer Resolution Status ===" "Info"
    
    # Check registry setting
    try {
        $globalEnabled = (Get-ItemProperty `
          -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
          -Name "GlobalTimerResolutionRequests" `
          -ErrorAction SilentlyContinue).GlobalTimerResolutionRequests
        if ($globalEnabled -eq 1) {
            Write-StatusMessage "Global Timer Resolution: ENABLED" "Success"
        } else {
            Write-StatusMessage "Global Timer Resolution: Not set or disabled" "Warning"
        }
    } catch {
        Write-StatusMessage "Global Timer Resolution: Unable to check registry" "Warning"
    }
    
    # Check if process is running
    $runningProcess = Get-Process -Name "SetTimerResolution" -ErrorAction SilentlyContinue
    if ($runningProcess) {
        Write-StatusMessage "SetTimerResolution process: RUNNING (PID: $($runningProcess.Id))" "Success"
    } else {
        Write-StatusMessage "SetTimerResolution process: Not running" "Warning"
    }
    
    # Check scheduled task
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-StatusMessage "Scheduled task: EXISTS (State: $($task.State))" "Success"
    } else {
        Write-StatusMessage "Scheduled task: NOT FOUND" "Warning"
    }
}

# ==================== MAIN EXECUTION ====================

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-StatusMessage "This script requires Administrator privileges. Please run as administrator." "Error"
    exit 1
}

Write-StatusMessage "=== Enabling Global Timer Resolution for Windows ===" "Info"
Write-StatusMessage "" "Info"

# Step 1: Select optimal timer resolution by measuring sleep accuracy
Write-StatusMessage "Step 1: Selecting optimal timer resolution (0.5ms – 0.6ms range)..." "Info"
try {
    $Resolution = Select-OptimalResolution
} catch {
    Write-StatusMessage "Resolution measurement failed: $($_.Exception.Message). Using default $Resolution." "Warning"
}
Write-StatusMessage "" "Info"

# Step 2: Enable registry key for global timer resolution
Write-StatusMessage "Step 2: Configuring registry for global timer resolution..." "Info"
try {
    Set-ItemProperty `
      -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
      -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-StatusMessage "Registry configured (GlobalTimerResolutionRequests = 1)" "Success"
} catch {
    Write-StatusMessage "Failed to configure registry: $($_.Exception.Message)" "Error"
}

# Step 3: Download/verify executable
Write-StatusMessage "" "Info"
Write-StatusMessage "Step 3: Checking/Downloading SetTimerResolution.exe..." "Info"
if (-not (Get-TimerResolutionExe)) {
    exit 1
}

# Step 4: Setup scheduled task
Write-StatusMessage "" "Info"
Write-StatusMessage "Step 4: Setting up scheduled task for autostart..." "Info"
if (-not (Set-TimerResolutionTask -Force)) {
    exit 1
}

# Step 5: Start timer resolution now
Write-StatusMessage "" "Info"
Write-StatusMessage "Step 5: Starting timer resolution now..." "Info"
Start-TimerResolutionNow | Out-Null

# Step 6: Check status
Get-TimerResolutionStatus

Write-StatusMessage "" "Info"
Write-StatusMessage ("Setup complete! Timer resolution ({0}ms / {1} * 100ns) will be applied at every logon." -f ($Resolution / 10000.0), $Resolution) "Success"
Write-StatusMessage "Executable location: $ExePath" "Info"
