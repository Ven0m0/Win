# Check for administrative privileges
function Check-AdminPrivileges {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "You need to run this script as an Administrator!"
        Read-Host "Press Enter to exit..."
        exit
    }
}

# Function to check if the PSWindowsUpdate module is installed
function Check-PSWindowsUpdateModule {
    $module = Get-Module -ListAvailable -Name PSWindowsUpdate
    return $module -ne $null
}

# Function to install the PSWindowsUpdate module
function Install-PSWindowsUpdateModule {
    Write-Output "PSWindowsUpdate module not found."
    $installModule = Read-Host "Do you want to install the PSWindowsUpdate module? (y/n)"
    if ($installModule -eq 'y') {
        try {
            Write-Output "Installing PSWindowsUpdate module..."
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
            Write-Output "PSWindowsUpdate module installed successfully."
        }
        catch {
            Write-Error "Failed to install PSWindowsUpdate module. Please try installing it manually."
            Read-Host "Press Enter to exit..."
            exit
        }
    }
    else {
        Write-Output "PSWindowsUpdate module installation declined. Exiting the script."
        Read-Host "Press Enter to exit..."
        exit
    }
}

# Check for administrative privileges
Check-AdminPrivileges

# Check if the PSWindowsUpdate module is installed, and install if necessary
if (-not (Check-PSWindowsUpdateModule)) {
    Install-PSWindowsUpdateModule
}

# Import the Windows Update module
Import-Module PSWindowsUpdate

# Check for available updates
Write-Output "Checking for Windows updates..."
$Updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot

if ($Updates.Count -eq 0) {
    Write-Output "No updates available."
    exit
}

# Display available updates
Write-Output "The following updates are available:"
$Updates | ForEach-Object { Write-Output "$($_.Title)" }

# Prompt the user to install updates
$install = Read-Host "Do you want to install the updates? (y/n)"

if ($install -eq 'y') {
    # Install updates and track progress
    Write-Output "Installing updates..."
    
    # Install the updates directly
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose
    
    # Check for installation status
    Write-Output "Installation complete. A reboot may be required to finish the installation."
} else {
    Write-Output "Updates were not installed."
}
