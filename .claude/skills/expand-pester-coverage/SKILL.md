# Expand Pester Test Coverage

Generate Pester tests for PowerShell functions, expanding test coverage across the repository.

---

## Purpose

Creates Pester test files (`.Tests.ps1`) that:
- Follow Arrange-Act-Assert pattern
- Mock registry operations safely (no HKLM mutations in tests)
- Test Common.ps1 utility functions
- Validate error handling and edge cases
- Integrate with CI/CD pipeline

**Invocation**: User-only (`/expand-pester-coverage`)

**Coverage goal**: All functions with complex logic (>15 lines) should have tests.

---

## Current Status

```
✓ Scripts/system-maintenance.Tests.ps1     (exists)
✓ Scripts/New-QueryString.Tests.ps1        (exists)
⚠ Scripts/*.ps1                             (remaining 13 scripts need tests)
```

---

## Test Template

```powershell
BeforeAll {
  Import-Module Pester -MinimumVersion 5.0

  # Mock external dependencies
  Mock -CommandName "Set-RegistryValue" -MockWith {
    param($Path, $Name, $Type, $Data)
    Write-Verbose "Mock registry: $Path\$Name"
  }

  Mock -CommandName "Get-NvidiaGpuRegistryPaths" -MockWith {
    return @("HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000")
  }

  # Source the script containing the function
  . "$PSScriptRoot\your-script.ps1"
}

Describe "Function-Name" {
  Context "Success scenario" {
    It "Should return expected value" {
      # Arrange
      $input = "test-value"

      # Act
      $result = Function-Name -Parameter $input

      # Assert
      $result | Should -Be "expected-output"
    }
  }

  Context "Error handling" {
    It "Should throw on invalid input" {
      {
        Function-Name -Parameter $null
      } | Should -Throw
    }
  }

  Context "Registry operations" {
    It "Should call Set-RegistryValue with correct path" {
      Function-Name

      Should -Invoke "Set-RegistryValue" -Times 1 -Scope Context -ParameterFilter {
        $Path -eq "HKLM:\SOFTWARE\Test"
      }
    }
  }
}
```

---

## Common Test Patterns

### Registry Mocking
```powershell
Mock -CommandName "Set-RegistryValue" -MockWith {
  param($Path, $Name, $Type, $Data)
  # Verify path/value without touching real registry
  $Path | Should -Match "HKLM:\\|HKCU:\\"
}
```

### NVIDIA GPU Path Mocking
```powershell
Mock -CommandName "Get-NvidiaGpuRegistryPaths" -MockWith {
  return @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001"
  )
}
```

### File Operations Mocking
```powershell
Mock -CommandName "Get-FileFromWeb" -MockWith {
  param($URL, $File)
  New-Item -Path $File -ItemType File -Force | Out-Null
}
```

### Menu Input Mocking
```powershell
Mock -CommandName "Get-MenuChoice" -MockWith {
  return 1  # Simulate user selecting first option
}
```

---

## Scripts Needing Test Coverage

| Script | Priority | Rationale |
|--------|----------|-----------|
| `Common.ps1` | 🔴 High | Core utilities; affects all scripts |
| `gpu-display-manager.ps1` | 🔴 High | NVIDIA registry ops; risk of GPU issues |
| `gaming-display.ps1` | 🟡 Medium | Display tweaks; complex logic |
| `steam.ps1` | 🟡 Medium | Steam config parsing (VDF) |
| `shader-cache.ps1` | 🟡 Medium | File operations |
| `DLSS-force-latest.ps1` | 🟡 Medium | NVIDIA DLSS registry tweaks |
| `Network-Tweaker.ps1` | 🟡 Medium | Network registry changes |
| `system-settings-manager.ps1` | 🟡 Medium | System registry paths |
| `UltimateDiskCleanup.ps1` | 🟢 Low | Disk cleanup; lower risk |
| `debloat-windows.ps1` | 🟢 Low | Cleanup script; lower risk |
| `shell-setup.ps1` | 🟢 Low | Shell config; non-destructive |
| `edid-manager.ps1` | 🟡 Medium | EDID files; critical for display |

---

## Running Tests Locally

```powershell
# Run all tests
Invoke-Pester -Path Scripts/

# Run specific test file
Invoke-Pester -Path Scripts/system-maintenance.Tests.ps1

# Run with coverage report
Invoke-Pester -Path Scripts/ -CodeCoverage Scripts/Common.ps1

# Run with verbose output
Invoke-Pester -Path Scripts/ -Verbose
```

---

## CI/CD Integration

Tests run automatically on:
- Push to `main` branch
- Pull requests
- Manual trigger (GitHub Actions)

View results in `.github/workflows/` logs.

---

## Next Steps

1. **Pick high-priority script** (e.g., `Common.ps1`)
2. **Use this skill** to generate test file
3. **Review & customize** test scenarios
4. **Run locally**: `Invoke-Pester -Path Scripts/Common.Tests.ps1`
5. **Commit**: `git add Scripts/Common.Tests.ps1 && git commit -m "test: Add Common.ps1 test coverage"`

---

## Related Skills

- **ps-script-validator** — Validates script quality
- **new-ps-script** — Generates scripts with testability in mind
