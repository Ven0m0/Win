#Requires -Version 5.1

BeforeDiscovery {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:notAdmin = -not ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# The script has '#Requires -RunAsAdministrator', so it can only be invoked from an elevated session.
# Top-level script (no dispatcher guard); invoked with '&' after every uninstall, winget, extraction,
# file-removal, and shortcut command is mocked.
Describe 'install-gmk-driver.ps1' -Skip:$notAdmin {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $scriptDir = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/third-party/gmk'
    $script:scriptPath = Join-Path -Path $scriptDir -ChildPath 'install-gmk-driver.ps1'
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $script:oldDest = Join-Path -Path $env:ProgramFiles -ChildPath 'GMKDriver'
    $script:newDest = Join-Path -Path $documents -ChildPath 'GMKDriver'
    # Stands in for 7z.exe: '& $7z' resolves the command name, so a function can replace the binary.
    function fake7z { }
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share state through a reference object.
    $gmkState = @{
      ExitCode   = 0
      ExePresent = $true
      OldPresent = $false
      Entries    = @()
    }
    Mock Request-AdminElevation { }
    Mock Initialize-ConsoleUI { }
    Mock Get-ItemProperty { $gmkState.Entries }
    Mock Stop-Process { }
    Mock Start-Process { }
    Mock Invoke-Winget { }
    Mock Test-Path {
      if ($LiteralPath -like '*GMKDriverNetUI.exe') { $gmkState.ExePresent } else { $gmkState.OldPresent }
    }
    Mock Remove-Item { }
    Mock Get-7zPath { 'fake7z' }
    Mock fake7z { $global:LASTEXITCODE = $gmkState.ExitCode }
    Mock Ensure-Directory { }
    Mock New-Shortcut { }
    Mock Write-Info { }
    Mock Write-Success { }
  }

  It 'Requests elevation and installs ViGEmBus through winget' {
    & $scriptPath

    Should -Invoke Request-AdminElevation -Times 1 -Exactly
    Should -Invoke Invoke-Winget -Times 1 -Exactly -ParameterFilter {
      $Id -eq 'ViGEm.ViGEmBus' -and $Name -eq 'ViGEmBus'
    }
  }

  It 'Leaves processes alone when no ClickOnce install exists' {
    & $scriptPath

    Should -Invoke Stop-Process -Times 0
    Should -Invoke Start-Process -Times 0
  }

  It 'Stops the running driver and runs the ClickOnce uninstaller when present' {
    $gmkState.Entries = @(
      [pscustomobject]@{
        DisplayName     = 'Gaming Mod Kits Controller Driver'
        UninstallString = 'rundll32 dfshim.dll,ShArpMaintain GMK'
      }
    )

    & $scriptPath

    Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Name -eq 'GMKDriverNetUI' }
    Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
      $FilePath -eq 'cmd.exe' -and $ArgumentList -eq '/c rundll32 dfshim.dll,ShArpMaintain GMK'
    }
  }

  It 'Ignores uninstall entries for other products' {
    $gmkState.Entries = @([pscustomobject]@{ DisplayName = 'Some Other App'; UninstallString = 'x' })

    & $scriptPath

    Should -Invoke Start-Process -Times 0
  }

  It 'Removes the previous Program Files install when it exists' {
    $gmkState.OldPresent = $true

    & $scriptPath

    Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter {
      $LiteralPath -eq $oldDest -and $Recurse -and $Force
    }
  }

  It 'Keeps the Program Files folder untouched when it is absent' {
    & $scriptPath

    Should -Invoke Remove-Item -Times 0
  }

  It 'Extracts GMKDriver.7z into Documents\GMKDriver' {
    & $scriptPath

    Should -Invoke Ensure-Directory -Times 1 -Exactly -ParameterFilter { $Path -eq $newDest }
    Should -Invoke fake7z -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq 'x' -and $args[1] -eq "-o$newDest" -and $args[2] -eq '-y' -and $args[3] -like '*GMKDriver.7z'
    }
  }

  It 'Creates Desktop, Start Menu, and Startup shortcuts to the driver executable' {
    & $scriptPath

    $exe = Join-Path -Path $newDest -ChildPath 'GMKDriverNetUI.exe'
    Should -Invoke New-Shortcut -Times 3 -Exactly -ParameterFilter {
      $TargetPath -eq $exe -and $ShortcutPath -like '*GMK Driver.lnk' -and $IconLocation -like '*.ico'
    }
    foreach ($folder in 'Desktop', 'Programs', 'Startup') {
      $link = Join-Path -Path ([Environment]::GetFolderPath($folder)) -ChildPath 'GMK Driver.lnk'
      Should -Invoke New-Shortcut -Times 1 -Exactly -ParameterFilter { $ShortcutPath -eq $link }
    }
  }

  It 'Throws with the exit code when 7z fails' {
    $gmkState.ExitCode = 7

    { & $scriptPath } | Should -Throw '*7z extraction failed with exit code 7*'
    Should -Invoke New-Shortcut -Times 0
  }

  It 'Throws without creating shortcuts when the executable is missing after extraction' {
    $gmkState.ExePresent = $false

    { & $scriptPath } | Should -Throw '*GMKDriverNetUI.exe not found after extraction*'
    Should -Invoke New-Shortcut -Times 0
    Should -Invoke Write-Success -Times 0
  }
}
