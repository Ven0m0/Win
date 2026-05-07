# Requires: PowerShell 5.1 or later with Administrator privileges
# This script enables global timer resolution and optionally sets up a scheduled task to persist the timer resolution on logon

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExePath = Join-Path $ScriptDir "SetTimerResolution.exe"
$DownloadUrl = "https://github.com/valleyofdoom/TimerResolution/releases/download/SetTimerResolution-v1.0.0/SetTimerResolution.exe"
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

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-StatusMessage "This script requires Administrator privileges. Please run as administrator." "Error"
    exit 1
}

Write-StatusMessage "Enabling Global Timer Resolution for Windows 11..." "Info"

# Step 1: Enable registry key for global timer resolution
Write-StatusMessage "Setting GlobalTimerResolutionRequests registry key..." "Info"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-StatusMessage "Registry key set successfully (GlobalTimerResolutionRequests = 1)" "Success"
} catch {
    Write-StatusMessage "Failed to set registry key: $($_.Exception.Message)" "Error"
}

# Step 2: Download SetTimerResolution.exe if not present
Write-StatusMessage "Checking for SetTimerResolution.exe..." "Info"
if (-not (Test-Path $ExePath)) {
    Write-StatusMessage "SetTimerResolution.exe not found. Downloading from GitHub..." "Warning"
    try {
        # Create WebClient for download with TLS 1.2 support
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DownloadUrl, $ExePath)
        
        if (Test-Path $ExePath) {
            Write-StatusMessage "SetTimerResolution.exe downloaded successfully" "Success"
        } else {
            throw "Download completed but file not found"
        }
    } catch {
        Write-StatusMessage "Failed to download SetTimerResolution.exe: $($_.Exception.Message)" "Error"
        exit 1
    }
} else {
    Write-StatusMessage "SetTimerResolution.exe already exists" "Success"
}

# Step 3: Check if scheduled task already exists
Write-StatusMessage "Checking for existing scheduled task '$TaskName'..." "Info"
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-StatusMessage "Scheduled task '$TaskName' already exists" "Info"
    Write-StatusMessage "Current task state: $($existingTask.State)" "Info"
    
    # Ask if user wants to update the task
    $response = Read-Host "Do you want to recreate the task to ensure it's configured correctly? (Y/N) [N]"
    if ($response -match '^[Yy]') {
        Write-StatusMessage "Removing existing task..." "Info"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        $existingTask = $null
    }
}

if (-not $existingTask) {
    Write-StatusMessage "Creating scheduled task '$TaskName'..." "Info"
    
    try {
        # Create the action to run SetTimerResolution.exe with parameters
        # --resolution 5040 = 0.504ms (in 100ns units)
        # --no-console = run without showing console window
        $action = New-ScheduledTaskAction -Execute $ExePath -Argument "--resolution $Resolution --no-console"
        
        # Create trigger: at logon, for any user
        $trigger = New-ScheduledTaskTrigger -AtLogon
        
        # Create settings: allow start on demand, run whether user is logged on or not
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        # Create principal: run with highest privileges
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # Register the task
        $task = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop
        
        Write-StatusMessage "Scheduled task '$TaskName' created successfully" "Success"
        Write-StatusMessage "Task will run at: At Logon" "Info"
        Write-StatusMessage "Timer resolution: 0.504ms (5040 * 100ns)" "Info"
        
        # Start the task now to apply the timer resolution immediately
        Write-StatusMessage "Starting the timer resolution service now..." "Info"
        try {
            Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
            Start-Sleep -Seconds 1
            $taskInfo = Get-ScheduledTask -TaskName $TaskName
            Write-StatusMessage "Task is now running (State: $($taskInfo.State))" "Success"
        } catch {
            # If scheduled task fails to start, try running directly
            Write-StatusMessage "Could not start via Task Scheduler, running executable directly..." "Warning"
            try {
                $process = Start-Process -FilePath $ExePath -ArgumentList "--resolution $Resolution --no-console" -WindowStyle Hidden -PassThru
                Write-StatusMessage "SetTimerResolution started directly (PID: $($process.Id))" "Success"
            } catch {
                Write-StatusMessage "Failed to start SetTimerResolution: $($_.Exception.Message)" "Error"
            }
        }
        
    } catch {
        Write-StatusMessage "Failed to create scheduled task: $($_.Exception.Message)" "Error"
        exit 1
    }
}

# Step 4: Verify current timer resolution
Write-StatusMessage "" "Info"
Write-StatusMessage "=== Timer Resolution Status ===" "Info"
try {
    $clockRate = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue).GlobalTimerResolutionRequests
    if ($clockRate -eq 1) {
        Write-StatusMessage "Global Timer Resolution Requests: ENABLED" "Success"
    } else {
        Write-StatusMessage "Global Timer Resolution Requests: Not set or disabled" "Warning"
    }
} catch {
    Write-StatusMessage "Could not verify registry setting" "Warning"
}

# Check if SetTimerResolution process is running
$runningProcess = Get-Process -Name "SetTimerResolution" -ErrorAction SilentlyContinue
if ($runningProcess) {
    Write-StatusMessage "SetTimerResolution process is RUNNING (PID: $($runningProcess.Id))" "Success"
} else {
    Write-StatusMessage "SetTimerResolution process is NOT running" "Warning"
}

Write-StatusMessage "" "Info"
Write-StatusMessage "Setup complete! The system will apply 0.504ms timer resolution at each logon." "Success"
