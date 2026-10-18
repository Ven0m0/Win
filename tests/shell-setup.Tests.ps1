#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

Describe "shell-setup.ps1" {
  Context "Script execution guard" {
    It "Should not execute main logic when dot-sourced" {
      # Dot-source the script, passing switches to prevent it from prompting
      . "$PSScriptRoot/../Scripts/shell-setup.ps1" -HomeWorkstation
      # If the script dot-sourced correctly without hanging, it passes
      $true | Should -Be $true
    }
  }

  Context "Function Definitions" {
    BeforeAll {
      . "$PSScriptRoot/../Scripts/shell-setup.ps1" -HomeWorkstation
    }

    It "Should define required functions" {
      Get-Command Invoke-Elevated -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Install-ScoopApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Install-ChocoApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Expand-Download -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Get-CustomApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Install-CustomApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Install-CustomPackage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      Get-Command Enable-Bucket -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
  }
}

# Every helper below is exercised with its external commands (scoop, choco, 7z, aria2c, curl.exe, Start-Process)
# replaced by stubs or mocks, so no package is installed and no process is started.
Describe "shell-setup.ps1 helpers" {
  BeforeAll {
    function scoop { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    function choco { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    function 7z { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    function aria2c { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    . "$PSScriptRoot/../Scripts/shell-setup.ps1" -HomeWorkstation
    # Dot-sourcing sets this to 'Continue'; keep the test output quiet
    $VerbosePreference = 'SilentlyContinue'
  }

  Context "Invoke-Elevated" {
    BeforeEach {
      $procState = @{ ExitCode = 0; Waited = 0 }
      Mock Start-Process {
        $proc = [pscustomobject]@{ ExitCode = $procState.ExitCode }
        Add-Member -InputObject $proc -MemberType ScriptMethod -Name WaitForExit -Value { $procState.Waited++ }
        $proc
      }
    }

    It "Starts the process with the RunAs verb" {
      Invoke-Elevated -FilePath 'tool.exe' -ArgumentList '/x'

      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
        $FilePath -eq 'tool.exe' -and $Verb -eq 'RunAs' -and $PassThru
      }
      $procState.Waited | Should -Be 1
    }

    It "Hides the window with -Hidden" {
      Invoke-Elevated -FilePath 'tool.exe' -Hidden

      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $WindowStyle -eq 'Hidden' }
    }

    It "Throws when the elevated command exits non-zero" {
      $procState.ExitCode = 5

      { Invoke-Elevated -FilePath 'tool.exe' } | Should -Throw '*Command failed: tool.exe*exit 5*'
    }

    It "Neither waits nor throws with -NoWait" {
      $procState.ExitCode = 5

      { Invoke-Elevated -FilePath 'tool.exe' -NoWait } | Should -Not -Throw
      $procState.Waited | Should -Be 0
    }

    It "Requires FilePath" {
      $attr = (Get-Command Invoke-Elevated).Parameters['FilePath'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
      $attr.Mandatory | Should -BeTrue
    }
  }

  Context "Install-ScoopApp" {
    It "Installs a package that scoop does not report as installed" {
      Mock scoop { [pscustomobject]@{ Installed = $false } } -ParameterFilter { $Rest -contains 'info' }
      Mock scoop { } -ParameterFilter { $Rest -contains 'install' }

      Install-ScoopApp -Package 'git'

      Should -Invoke scoop -Times 1 -Exactly -ParameterFilter { $Rest -contains 'install' -and $Rest -contains 'git' }
    }

    It "Skips a package that is already installed" {
      Mock scoop { [pscustomobject]@{ Installed = $true } } -ParameterFilter { $Rest -contains 'info' }
      Mock scoop { } -ParameterFilter { $Rest -contains 'install' }

      Install-ScoopApp -Package 'git'

      Should -Invoke scoop -Times 0 -Exactly -ParameterFilter { $Rest -contains 'install' }
    }
  }

  Context "Install-ChocoApp" {
    BeforeEach {
      Mock Invoke-Elevated { }
    }

    It "Installs through an elevated choco call when the package is missing" {
      Mock choco { '0 packages installed.' }

      Install-ChocoApp -Package 'sometool'

      Should -Invoke Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
        $FilePath -eq 'PowerShell' -and $ArgumentList -contains 'install' -and $ArgumentList -contains 'sometool'
      }
    }

    It "Skips a package that is already installed" {
      Mock choco { 'sometool 1.0', '1 packages installed.' }

      Install-ChocoApp -Package 'sometool'

      Should -Invoke Invoke-Elevated -Times 0 -Exactly
    }
  }

  Context "Expand-Download" {
    BeforeEach {
      Mock 7z { }
      Mock Start-Process { }
      $folder = Join-Path $TestDrive 'out'
      $null = New-Item -Path $folder -ItemType Directory -Force
    }

    It "Throws when the destination folder does not exist" {
      { Expand-Download -Folder (Join-Path $TestDrive 'missing') -File (Join-Path $TestDrive 'a.zip') } |
        Should -Throw '*does not exist*'
    }

    It "Extracts <ext> archives with 7z" -ForEach @(
      @{ ext = 'zip' }, @{ ext = '7z' }, @{ ext = 'exe' }, @{ ext = 'ZIP' }
    ) {
      $file = Join-Path $TestDrive "archive.$ext"
      Set-Content -LiteralPath $file -Value 'x'

      Expand-Download -Folder $folder -File $file

      Should -Invoke 7z -Times 1 -Exactly
      Should -Invoke Start-Process -Times 0 -Exactly
    }

    It "Extracts rar archives through UnRar.exe" {
      $file = Join-Path $TestDrive 'archive.rar'
      Set-Content -LiteralPath $file -Value 'x'

      Expand-Download -Folder $folder -File $file

      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'UnRar.exe' }
      Should -Invoke 7z -Times 0 -Exactly
    }

    It "Throws for an extension with no extractor" {
      $file = Join-Path $TestDrive 'notes.txt'
      Set-Content -LiteralPath $file -Value 'x'

      { Expand-Download -Folder $folder -File $file } | Should -Throw '*No extractor for*'
    }

    It "Does nothing when the archive file does not exist" {
      { Expand-Download -Folder $folder -File (Join-Path $TestDrive 'gone.zip') } | Should -Not -Throw
      Should -Invoke 7z -Times 0 -Exactly
    }
  }

  Context "Get-CustomApp" {
    BeforeEach {
      Mock aria2c { }
    }

    It "Uses the Content-Disposition file name when the server sends one" {
      Mock curl.exe { 'HTTP/1.1 200 OK', 'Content-Disposition: attachment; filename="real-name.zip"' }

      Get-CustomApp -Link 'https://example.invalid/download?id=1' -Folder $TestDrive | Should -Be 'real-name.zip'
    }

    It "Falls back to the last URL segment" {
      Mock curl.exe { 'HTTP/1.1 200 OK' }

      Get-CustomApp -Link 'https://example.invalid/files/tool.7z' -Folder $TestDrive | Should -Be 'tool.7z'
    }

    It "Downloads the link into the requested folder with aria2c" {
      Mock curl.exe { 'HTTP/1.1 200 OK' }

      $null = Get-CustomApp -Link 'https://example.invalid/files/tool.7z' -Folder $TestDrive

      Should -Invoke aria2c -Times 1 -Exactly
    }
  }

  Context "Install-CustomApp" {
    BeforeEach {
      Mock Get-CustomApp { 'pkg.zip' }
      Mock Expand-Download { }
      Mock Remove-Item { }
      Mock New-Item { }
      Mock Test-Path { $true }
    }

    It "Extracts into the bin folder and removes the download" {
      Install-CustomApp -URL 'https://example.invalid/pkg.zip'

      Should -Invoke Expand-Download -Times 1 -Exactly -ParameterFilter {
        $Folder -like '*\bin\' -and $File -like '*Downloads*pkg.zip'
      }
      Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter { $LiteralPath -like '*pkg.zip' }
    }

    It "Extracts into a named sub-folder when -Folder is given" {
      Install-CustomApp -URL 'https://example.invalid/pkg.zip' -Folder 'tools'

      Should -Invoke Expand-Download -Times 1 -Exactly -ParameterFilter { $Folder -like '*\bin\tools' }
    }

    It "Creates the sub-folder when it does not exist" {
      Mock Test-Path { $LiteralPath -like '*pkg.zip' } -ParameterFilter { $true }

      Install-CustomApp -URL 'https://example.invalid/pkg.zip' -Folder 'tools'

      Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $ItemType -eq 'Directory' }
    }

    It "Does nothing when the download is missing" {
      Mock Test-Path { $false }

      Install-CustomApp -URL 'https://example.invalid/pkg.zip'

      Should -Invoke Expand-Download -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context "Install-CustomPackage" {
    BeforeEach {
      Mock Get-CustomApp { 'setup.exe' }
      Mock Invoke-Elevated { }
      Mock Remove-Item { }
      Mock Test-Path { $true }
    }

    It "Runs the installer silently and elevated, then deletes it" {
      Install-CustomPackage -URL 'https://example.invalid/setup.exe'

      Should -Invoke Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
        $FilePath -eq '.\setup.exe' -and $ArgumentList -contains '/S' -and $Hidden
      }
      Should -Invoke Remove-Item -Times 1 -Exactly
    }

    It "Does nothing when the download is missing" {
      Mock Test-Path { $false }

      Install-CustomPackage -URL 'https://example.invalid/setup.exe'

      Should -Invoke Invoke-Elevated -Times 0 -Exactly
      Should -Invoke Remove-Item -Times 0 -Exactly
    }
  }

  Context "Enable-Bucket" {
    It "Adds a bucket that is not listed" {
      Mock scoop { [pscustomobject]@{ Name = 'main' } } -ParameterFilter { $Rest -contains 'list' }
      Mock scoop { } -ParameterFilter { $Rest -contains 'add' }

      Enable-Bucket -Bucket 'extras'

      Should -Invoke scoop -Times 1 -Exactly -ParameterFilter { $Rest -contains 'add' -and $Rest -contains 'extras' }
    }

    It "Skips a bucket that is already added" {
      Mock scoop { [pscustomobject]@{ Name = 'main' }, [pscustomobject]@{ Name = 'extras' } } `
        -ParameterFilter { $Rest -contains 'list' }
      Mock scoop { } -ParameterFilter { $Rest -contains 'add' }

      Enable-Bucket -Bucket 'extras'

      Should -Invoke scoop -Times 0 -Exactly -ParameterFilter { $Rest -contains 'add' }
    }
  }
}
