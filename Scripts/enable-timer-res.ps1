#Requires -Version 5.1
# Requires Administrator privileges
# This script enables global timer resolution and sets up a scheduled task to persist the timer resolution on logon

# Configuration
$ExePath = "C:\SetTimerResolution.exe"
$DownloadUrl = "https://github.com/valleyofdoom/TimerResolution/releases/download/" + `
  "SetTimerResolution-v1.0.0/SetTimerResolution.exe"
$TaskName = "SetTimerResolution-AutoStart"
$Resolution = 5040  # 0.504ms in 100ns units (0.504 * 10000 = 5040)

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

# Function to download SetTimerResolution.exe
function Get-TimerResolutionExe {
    Write-StatusMessage "Checking for SetTimerResolution.exe at $ExePath..." "Info"
    if (Test-Path $ExePath) {
        Write-StatusMessage "SetTimerResolution.exe already exists at C:\" "Success"
        return $true
    }
    
    Write-StatusMessage "SetTimerResolution.exe not found. Downloading from GitHub..." "Warning"
    try {
        # Enable TLS 1.2 for secure download
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DownloadUrl, $ExePath)
        
        if (Test-Path $ExePath) {
            Write-StatusMessage "SetTimerResolution.exe downloaded successfully to C:\" "Success"
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
        # Create the action to run SetTimerResolution.exe with parameters
        # --resolution 5040 = 0.504ms (in 100ns units)
        # --no-console = run without showing console window
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
        Write-StatusMessage "Timer resolution: 0.504ms (5040 * 100ns)" "Info"
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

# Step 1: Enable registry key for global timer resolution
Write-StatusMessage "Step 1: Configuring registry for global timer resolution..." "Info"
try {
    Set-ItemProperty `
      -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
      -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-StatusMessage "Registry configured (GlobalTimerResolutionRequests = 1)" "Success"
} catch {
    Write-StatusMessage "Failed to configure registry: $($_.Exception.Message)" "Error"
}

# Step 2: Download/verify executable
Write-StatusMessage "" "Info"
Write-StatusMessage "Step 2: Checking/Downloading SetTimerResolution.exe..." "Info"
if (-not (Get-TimerResolutionExe)) {
    exit 1
}

# Step 3: Setup scheduled task
Write-StatusMessage "" "Info"
Write-StatusMessage "Step 3: Setting up scheduled task for autostart..." "Info"
if (-not (Set-TimerResolutionTask)) {
    exit 1
}

# Step 4: Start timer resolution now
Write-StatusMessage "" "Info"
Write-StatusMessage "Step 4: Starting timer resolution now..." "Info"
Start-TimerResolutionNow | Out-Null

# Step 5: Check status
Get-TimerResolutionStatus

Write-StatusMessage "" "Info"
Write-StatusMessage "Setup complete! Timer resolution (0.504ms) will be applied at every logon." "Success"
Write-StatusMessage "Executable location: C:\SetTimerResolution.exe" "Info"
