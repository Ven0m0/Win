#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# Top-level script that deletes and moves files next to itself in Scripts/reg, so every file, download, and
# extraction command is mocked before it is invoked with '&'. Pester mocks are aliases, so they still win
# after the script re-dot-sources Common.ps1.
Describe 'reg/cleanup.ps1' {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/reg/cleanup.ps1'
    # Stand in for the 7z.exe and tar.exe binaries the extraction helper shells out to.
    function fake7z { }
    function tar { }
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share state through a reference object.
    $cleanState = @{
      SevenZip = [pscustomobject]@{ Source = 'fake7z' }
      Tar      = [pscustomobject]@{ Source = 'tar' }
      X64      = $false
      Win32    = $false
    }
    # Unrelated lookups (e.g. from Common.ps1) fall through to the real cmdlets.
    Mock Get-Command {
      if ($Name -contains '7z') { $cleanState.SevenZip }
      elseif ($Name -contains 'tar') { $cleanState.Tar }
      else { Microsoft.PowerShell.Core\Get-Command @PesterBoundParameters }
    }
    Mock Test-Path {
      if ($Path -like '*\x64') { $cleanState.X64 }
      elseif ($Path -like '*\Win32') { $cleanState.Win32 }
      else { Microsoft.PowerShell.Management\Test-Path @PesterBoundParameters }
    }
    Mock Get-FileFromWeb { }
    Mock fake7z { }
    Mock tar { }
    Mock Expand-Archive { }
    Mock Move-Item { }
    Mock Remove-Item { }
  }

  Context 'Download' {
    It 'Fetches both utilities from uwe-sieber.de into the script folder' {
      & $scriptPath

      Should -Invoke Get-FileFromWeb -Times 1 -Exactly -ParameterFilter {
        $URL -eq 'https://www.uwe-sieber.de/files/DeviceCleanup_x64.zip' -and $File -like '*\DeviceCleanup.zip'
      }
      Should -Invoke Get-FileFromWeb -Times 1 -Exactly -ParameterFilter {
        $URL -eq 'https://www.uwe-sieber.de/files/DriveCleanup.zip' -and $File -like '*\DriveCleanup.zip'
      }
    }

    It 'Removes stale zip, txt, and exe files before downloading' {
      & $scriptPath

      Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter {
        @($Path).Count -eq 3 -and $Path[0] -like '*\DeviceCleanup.zip' -and $Path[2] -like '*\DeviceCleanup.exe'
      }
    }

    It 'Removes the intermediate zip and txt but keeps the exe' {
      & $scriptPath

      Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter {
        @($Path).Count -eq 2 -and $Path[0] -like '*\DriveCleanup.zip' -and $Path[1] -like '*\DriveCleanup.txt'
      }
    }

    It 'Stops without extracting when the download fails' {
      Mock Get-FileFromWeb { throw 'network down' }

      { & $scriptPath } | Should -Throw '*network down*'
      Should -Invoke fake7z -Times 0
      Should -Invoke Expand-Archive -Times 0
    }
  }

  Context 'Dry run' {
    It 'Downloads and deletes nothing with -DryRun' {
      & $scriptPath -DryRun

      Should -Invoke Get-FileFromWeb -Times 0
      Should -Invoke Remove-Item -Times 0
    }

    It 'Downloads and deletes nothing with -WhatIf' {
      & $scriptPath -WhatIf

      Should -Invoke Get-FileFromWeb -Times 0
      Should -Invoke Remove-Item -Times 0
    }
  }

  Context 'Extraction' {
    It 'Prefers 7-Zip when available' {
      & $scriptPath

      Should -Invoke fake7z -Times 2 -Exactly -ParameterFilter {
        $args[0] -eq 'x' -and $args[1] -eq '-y' -and $args[2] -like '-o*' -and $args[3] -like '*.zip'
      }
      Should -Invoke tar -Times 0
      Should -Invoke Expand-Archive -Times 0
    }

    It 'Uses tar when 7-Zip is missing' {
      $cleanState.SevenZip = $null

      & $scriptPath

      Should -Invoke tar -Times 2 -Exactly -ParameterFilter { $args[0] -eq '-xf' -and $args[2] -eq '-C' }
      Should -Invoke fake7z -Times 0
      Should -Invoke Expand-Archive -Times 0
    }

    It 'Falls back to Expand-Archive when neither 7-Zip nor tar exists' {
      $cleanState.SevenZip = $null
      $cleanState.Tar = $null

      & $scriptPath

      Should -Invoke Expand-Archive -Times 2 -Exactly -ParameterFilter { $Path -like '*.zip' -and $Force }
      Should -Invoke fake7z -Times 0
      Should -Invoke tar -Times 0
    }
  }

  Context 'Architecture subfolders' {
    It 'Flattens the x64 folder into the script folder and deletes it' {
      $cleanState.X64 = $true

      & $scriptPath

      Should -Invoke Move-Item -Times 2 -Exactly -ParameterFilter {
        $Path -like '*\x64\*' -and $Destination -notlike '*\x64*' -and $Force
      }
      Should -Invoke Remove-Item -Times 2 -Exactly -ParameterFilter {
        $Path -like '*\x64' -and $Recurse -and $Force
      }
    }

    It 'Deletes the Win32 folder' {
      $cleanState.Win32 = $true

      & $scriptPath

      Should -Invoke Remove-Item -Times 2 -Exactly -ParameterFilter { $Path -like '*\Win32' -and $Recurse }
    }

    It 'Leaves the folder alone when no architecture subfolders were extracted' {
      & $scriptPath

      Should -Invoke Move-Item -Times 0
      Should -Invoke Remove-Item -Times 0 -ParameterFilter { $Recurse }
    }
  }
}
