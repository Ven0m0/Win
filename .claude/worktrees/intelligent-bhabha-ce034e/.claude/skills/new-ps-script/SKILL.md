# New PowerShell Script Template

Scaffold a new PowerShell script with best-practice boilerplate and helper utilities.

---

## Purpose

Generates a `.ps1` script template that:
- Includes required headers (#Requires, Common.ps1 import)
- Sets up admin elevation & console UI
- Provides interactive menu structure
- Includes registry operation examples
- Follows AGENTS.md conventions out-of-the-box

**Invocation**: User-only (`/new-ps-script`)

---

## Quick Usage

```powershell
/new-ps-script --name my-feature-script --description "Brief description"
```

Generates: `Scripts/my-feature-script.ps1`

---

## Generated Template

```powershell
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"

Request-AdminElevation
Initialize-ConsoleUI -Title "My Feature Script (Administrator)"

<#
.SYNOPSIS
    Brief description of what this script does

.DESCRIPTION
    Longer description explaining the feature, use cases, and any important details.

.EXAMPLE
    . "$PSScriptRoot\my-feature-script.ps1"
    Select menu option to run features
#>

# Function template with proper error handling
function Enable-Feature {
  param(
    [Parameter(Mandatory)]
    [string]$FeatureName
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = "Stop"

  try {
    Write-Host "Enabling $FeatureName..."
    Set-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature" -Type "REG_DWORD" -Data "1"
    Write-Host "✓ $FeatureName enabled"
  } catch {
    Write-Error "Failed to enable $FeatureName: $_"
    return $false
  }
}

function Disable-Feature {
  param(
    [Parameter(Mandatory)]
    [string]$FeatureName
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = "Stop"

  try {
    Write-Host "Disabling $FeatureName..."
    Remove-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature"
    Write-Host "✓ $FeatureName disabled"
  } catch {
    Write-Error "Failed to disable $FeatureName: $_"
    return $false
  }
}

# Main menu loop
while ($true) {
  Show-Menu -Title "Feature Manager" -Options @("Enable", "Disable", "Exit")
  $choice = Get-MenuChoice -Min 1 -Max 3

  switch ($choice) {
    1 { Enable-Feature -FeatureName "MyFeature" }
    2 { Disable-Feature -FeatureName "MyFeature" }
    3 { exit }
  }

  Read-Host "`nPress Enter to continue"
}
```

---

## Template Customization Points

| Section | Example | Use For |
|---------|---------|---------|
| `#Requires` | `-RunAsAdministrator` | Admin scripts only |
| `.SYNOPSIS` | "One-line summary" | Help text |
| `.DESCRIPTION` | Multi-line explanation | Detailed help |
| `Initialize-ConsoleUI -Title` | "Script Name (Administrator)" | Console window title |
| Function names | `Enable-Feature` | Verb-Noun pattern |
| Registry paths | `HKLM\SOFTWARE\...` | System config |
| Error handling | `try/catch`, `Set-StrictMode` | Production safety |
| Menu options | `@("Option 1", "Option 2")` | Interactive UI |

---

## Common Script Types

### Registry Tweak Script
```powershell
function Set-NvidiaOptimization {
  $gpuPaths = Get-NvidiaGpuRegistryPaths
  foreach ($path in $gpuPaths) {
    Set-RegistryValue -Path "$path" -Name "PowerManagementMode" -Type "REG_DWORD" -Data "1"
  }
}
```

### Download & Execute Script
```powershell
function Install-Tool {
  param([string]$ToolName, [string]$Url, [string]$Destination)
  Get-FileFromWeb -URL $Url -File $Destination
  & $Destination
}
```

### Directory Cleanup Script
```powershell
function Clean-Temp {
  Clear-DirectorySafe -Path "C:\Temp"
  Clear-DirectorySafe -Path "$env:TEMP"
}
```

### Steam Configuration Script
```powershell
function Update-SteamConfig {
  $vdfPath = "$env:PROGRAMFILES (x86)\Steam\userdata\*\config\localconfig.vdf"
  $config = ConvertFrom-VDF -Content (Get-Content $vdfPath)
  # Modify $config...
  ConvertTo-VDF -Data $config | Out-File $vdfPath
}
```

---

## Next Steps After Generation

1. **Replace template values**: `...` placeholders with real registry paths, filenames, etc.
2. **Add tests**: Create `my-feature-script.Tests.ps1` for complex functions
3. **Document parameters**: Add `.PARAMETER` sections for all function params
4. **Commit**: `git add Scripts/my-feature-script.ps1 && git commit -m "feat: Add my-feature-script"`

---

## Related Skills

- **ps-script-validator** — Validates your new script against conventions
- **expand-pester-coverage** — Generates Pester tests for your functions
