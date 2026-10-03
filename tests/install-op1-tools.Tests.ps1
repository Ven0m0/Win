#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# Top-level script (no dispatcher guard); invoked with '&' after 7-Zip, directory creation, and output
# helpers are mocked. Pester mocks are aliases, so they still win after the script re-dot-sources Common.ps1.
Describe 'install-op1-tools.ps1' {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $scriptDir = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/third-party/endgame-gear'
    $script:scriptPath = Join-Path -Path $scriptDir -ChildPath 'install-op1-tools.ps1'
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $script:expectedDest = Join-Path -Path $documents -ChildPath 'EndgameGear'
    # Stands in for 7z.exe: '& $7z' resolves the command name, so a function can replace the binary.
    function fake7z { }
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share state through a reference object.
    $op1State = @{ ExitCode = 0 }
    Mock Get-7zPath { 'fake7z' }
    Mock fake7z { $global:LASTEXITCODE = $op1State.ExitCode }
    Mock Ensure-Directory { }
    Mock Write-Info { }
    Mock Write-Success { }
  }

  It 'Creates the EndgameGear folder under Documents' {
    & $scriptPath

    Should -Invoke Ensure-Directory -Times 1 -Exactly -ParameterFilter { $Path -eq $expectedDest }
  }

  It 'Extracts the bundled archive into that folder with overwrite' {
    & $scriptPath

    Should -Invoke fake7z -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq 'x' -and
      $args[1] -eq "-o$expectedDest" -and
      $args[2] -eq '-y' -and
      $args[3] -like '*EndgameGear-OP1-8k-Tools.7z'
    }
  }

  It 'Reports success after a clean extraction' {
    & $scriptPath

    Should -Invoke Write-Success -Times 1 -Exactly
  }

  It 'Throws with the exit code when 7z fails' {
    $op1State.ExitCode = 2

    { & $scriptPath } | Should -Throw '*7z extraction failed with exit code 2*'
    Should -Invoke Write-Success -Times 0
  }

  It 'Stops before extracting when 7-Zip is not installed' {
    Mock Get-7zPath { throw '7-Zip (7z.exe) not found.' }

    { & $scriptPath } | Should -Throw '*7-Zip*not found*'
    Should -Invoke fake7z -Times 0
    Should -Invoke Ensure-Directory -Times 0
  }
}
