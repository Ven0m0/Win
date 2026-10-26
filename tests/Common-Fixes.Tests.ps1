#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/Common.ps1"
    # Stub so Pester can mock it; nothing real is ever invoked.
    function winget { param([Parameter(ValueFromRemainingArguments)]$Rest) }
}

Describe "Update-EnvironmentPath" {
    It "Keeps process-only entries and removes duplicates" {
        $saved = $env:Path
        try {
            $env:Path = 'C:\process-only-shim;' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
            Update-EnvironmentPath
            $entries = $env:Path -split ';'
            $entries | Should -Contain 'C:\process-only-shim'
            $normalized = $entries | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }
            ($normalized | Select-Object -Unique).Count | Should -Be $normalized.Count
        }
        finally { $env:Path = $saved }
    }
}

Describe "Install-WingetTool -NoPathRefresh" {
    It "Skips the PATH refresh on success" {
        Mock Write-Host { }
        Mock Wait-ForWinget { 'winget' }
        Mock Update-EnvironmentPath { }
        Mock winget { $global:LASTEXITCODE = 0 }

        Install-WingetTool -Id 'Git.Git' -NoPathRefresh

        Should -Invoke Update-EnvironmentPath -Times 0 -Exactly
    }
}

Describe "Invoke-Winget -Arguments" {
    BeforeEach {
        Mock Write-ColorOutput { }
        Mock Wait-ForWinget { 'winget' }
        $script:seen = $null
        Mock winget { $script:seen = $Rest; $global:LASTEXITCODE = 0 }
    }

    It "Keeps array elements with spaces intact" {
        Invoke-Winget -Id 'X.Y' -Arguments @('--location', 'C:\Program Files\X')
        $script:seen | Should -Contain 'C:\Program Files\X'
    }

    It "Still splits a single legacy string" {
        Invoke-Winget -Id 'X.Y' -Arguments '--override /silent'
        $script:seen | Should -Contain '--override'
        $script:seen | Should -Contain '/silent'
    }
}

Describe "Resolve-OrInstallTool -Optional" {
    It "Returns null instead of throwing when winget fails" {
        Mock Resolve-Tool { $null }
        Mock Invoke-Winget { throw 'winget exit code: 1' }
        Mock Update-EnvironmentPath { }
        Mock Write-Warning { }

        Resolve-OrInstallTool -Name 'nope' -WingetId 'No.Pe' -Optional | Should -BeNullOrEmpty
    }

    It "Still throws without -Optional" {
        Mock Resolve-Tool { $null }
        Mock Invoke-Winget { throw 'winget exit code: 1' }
        Mock Update-EnvironmentPath { }

        { Resolve-OrInstallTool -Name 'nope' -WingetId 'No.Pe' } | Should -Throw
    }
}

Describe "Get-SilentInstallSwitches" {
    It "Detects a framework signature by reading raw bytes" {
        $file = Join-Path -Path $TestDrive -ChildPath 'setup.exe'
        $bytes = [byte[]](0, 255, 128) + [Text.Encoding]::ASCII.GetBytes('Nullsoft Install System') + [byte[]](200, 1)
        [IO.File]::WriteAllBytes($file, $bytes)

        Get-SilentInstallSwitches -Path $file | Should -Be @('/S')
    }
}

Describe "Clear-DirectorySafe" {
    It "Empties the directory and leaves no helper directory behind" {
        $dir = Join-Path -Path $TestDrive -ChildPath 'target'
        $null = New-Item -Path (Join-Path -Path $dir -ChildPath 'sub') -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $dir -ChildPath 'sub\a.txt') -Value 'x'
        Set-Content -Path (Join-Path -Path $dir -ChildPath 'b.txt') -Value 'x'

        Clear-DirectorySafe -Path $dir

        @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
        Test-Path -LiteralPath (Join-Path -Path $dir -ChildPath '-EMPTY-') | Should -BeFalse
    }
}

Describe "Invoke-ServiceOperation" {
    It "Warns when the restart fails" {
        Mock Get-Service { [pscustomobject]@{ Status = 'Running' } }
        Mock Stop-Service { }
        Mock Start-Service { throw 'cannot start' }
        Mock Write-Warning { }

        Invoke-ServiceOperation -Name 'FakeSvc' -Action { } -Restart $true

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*FakeSvc*cannot start*" }
    }
}

Describe "Invoke-Operation -Command" {
    BeforeEach {
        Mock Write-Info { }
        Mock Write-Fail { }
        Mock Add-Log { }
        Mock Write-Warning { }
        $script:cmdExe = (Get-Command -Name cmd.exe -CommandType Application).Source
    }

    It "Records non-zero exit as FAILED on the capture path" {
        $results = @{}
        Invoke-Operation -Name 'op' -Action { } -Results $results -CaptureOutput -Command $script:cmdExe `
            -ArgumentList '/c exit 3'
        $results['op'] | Should -Be 'FAILED: Exit Code: 3'
        Should -Invoke Write-Warning -Times 1 -Exactly
    }

    It "Records non-zero exit as FAILED on the non-capture path" {
        $results = @{}
        Invoke-Operation -Name 'op' -Action { } -Results $results -Command $script:cmdExe -ArgumentList '/c exit 4'
        $results['op'] | Should -Be 'FAILED: Exit Code: 4'
    }

    It "Records success unchanged" {
        $results = @{}
        Invoke-Operation -Name 'op' -Action { } -Results $results -CaptureOutput -Command $script:cmdExe `
            -ArgumentList '/c exit 0'
        $results['op'] | Should -Be 'Exit Code: 0'
    }

    It "Does not deadlock on large stderr" {
        $results = @{}
        $argList = '/c for /l %i in (1,1,6000) do @echo 0123456789012345678901234567890123456789012345678901234567890 1>&2'
        Invoke-Operation -Name 'op' -Action { } -Results $results -CaptureOutput -Command $script:cmdExe `
            -ArgumentList $argList -TimeoutSeconds 60
        $results['op'] | Should -Be 'Exit Code: 0'
    }

    It "Times out on the capture path" {
        $results = @{}
        Invoke-Operation -Name 'op' -Action { } -Results $results -CaptureOutput -Command $script:cmdExe `
            -ArgumentList '/c ping -n 30 127.0.0.1 >nul' -TimeoutSeconds 1
        $results['op'] | Should -BeLike 'TIMEOUT*'
    }
}

Describe "Invoke-ToolAboveNormal" {
    It "Starts the tool and returns its output even under -WhatIf" {
        $cmdExe = (Get-Command -Name cmd.exe -CommandType Application).Source
        Mock Write-Host { }
        $WhatIfPreference = $true
        try {
            $result = Invoke-ToolAboveNormal -FilePath $cmdExe -ArgumentList @('/c', 'echo hello& exit 2')
        }
        finally { $WhatIfPreference = $false }
        $result.ExitCode | Should -Be 2
        $result.Output | Should -Contain 'hello'
    }
}

Describe "Set-NvidiaSignatureOverride -WhatIf" {
    It "Touches neither bcdedit, the registry, nor restore points" {
        Mock bcdedit.exe { $global:LASTEXITCODE = 0 }
        Mock New-RestorePoint { }
        Mock Set-RegistryValue { }
        Mock Write-ColorOutput { }

        Set-NvidiaSignatureOverride -Enabled $true -WhatIf

        Should -Invoke bcdedit.exe -Times 0 -Exactly
        Should -Invoke New-RestorePoint -Times 0 -Exactly
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
    }

    It "Creates a restore point first, unless -NoRestorePoint" {
        Mock bcdedit.exe { $global:LASTEXITCODE = 0 }
        Mock New-RestorePoint { }
        Mock Set-RegistryValue { }
        Mock Write-ColorOutput { }

        Set-NvidiaSignatureOverride -Enabled $true -Confirm:$false
        Set-NvidiaSignatureOverride -Enabled $true -Confirm:$false -NoRestorePoint

        Should -Invoke New-RestorePoint -Times 1 -Exactly
        Should -Invoke bcdedit.exe -Times 4 -Exactly
    }
}

Describe "Install-GitHubRelease" {
    BeforeEach {
        Mock Write-Info { }
        Mock Write-Success { }
        Mock Write-Error { }
        Mock Write-Warning { }
        $script:zip = Join-Path -Path $TestDrive -ChildPath 'asset.zip'
        $payload = Join-Path -Path $TestDrive -ChildPath 'payload'
        $null = New-Item -Path $payload -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $payload -ChildPath 'tool.exe') -Value 'new'
        Compress-Archive -Path (Join-Path -Path $payload -ChildPath '*') -DestinationPath $script:zip -Force
        $script:digest = 'sha256:' + (Get-FileHash -LiteralPath $script:zip -Algorithm SHA256).Hash.ToLowerInvariant()
        Mock Get-FileFromWeb { Copy-Item -LiteralPath $script:zip -Destination $File -Force }
        $script:dest = Join-Path -Path $TestDrive -ChildPath 'install'
        $null = New-Item -Path $script:dest -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $script:dest -ChildPath 'old.txt') -Value 'old'
    }

    It "Rejects a digest mismatch and keeps the old install" {
        Mock Get-GitHubReleaseAsset {
            [pscustomobject]@{ Name = 'asset.zip'; BrowserDownloadUrl = 'u'; ReleaseTag = 'v1'; Digest = 'sha256:' + ('0' * 64) }
        }
        { Install-GitHubRelease -Repository 'o/r' -AssetPattern '*.zip' -Name 'T' -InstallType Zip `
                -DestinationPath $script:dest -NoShortcuts } | Should -Throw '*SHA256 mismatch*'
        Test-Path -LiteralPath (Join-Path -Path $script:dest -ChildPath 'old.txt') | Should -BeTrue
    }

    It "Swaps the install after a verified extraction" {
        Mock Get-GitHubReleaseAsset {
            [pscustomobject]@{ Name = 'asset.zip'; BrowserDownloadUrl = 'u'; ReleaseTag = 'v1'; Digest = $script:digest }
        }
        Install-GitHubRelease -Repository 'o/r' -AssetPattern '*.zip' -Name 'T' -InstallType Zip `
            -DestinationPath $script:dest -NoShortcuts
        Test-Path -LiteralPath (Join-Path -Path $script:dest -ChildPath 'tool.exe') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path -Path $script:dest -ChildPath 'old.txt') | Should -BeFalse
    }

    It "Keeps the old install when extraction fails" {
        Mock Get-GitHubReleaseAsset {
            [pscustomobject]@{ Name = 'asset.zip'; BrowserDownloadUrl = 'u'; ReleaseTag = 'v1'; Digest = $null }
        }
        Mock Get-FileFromWeb { Set-Content -Path $File -Value 'not a zip' }
        { Install-GitHubRelease -Repository 'o/r' -AssetPattern '*.zip' -Name 'T' -InstallType Zip `
                -DestinationPath $script:dest -NoShortcuts } | Should -Throw
        Test-Path -LiteralPath (Join-Path -Path $script:dest -ChildPath 'old.txt') | Should -BeTrue
    }

    It "Fails when the Exe installer returns a non-zero exit code" {
        Mock Get-GitHubReleaseAsset {
            [pscustomobject]@{ Name = 'setup.exe'; BrowserDownloadUrl = 'u'; ReleaseTag = 'v1'; Digest = $null }
        }
        $cmdExe = (Get-Command -Name cmd.exe -CommandType Application).Source
        Mock Get-FileFromWeb { Copy-Item -LiteralPath $cmdExe -Destination $File -Force }
        { Install-GitHubRelease -Repository 'o/r' -ExactAssetName 'setup.exe' -Name 'T' -InstallType Exe `
                -Switches '/c', 'exit 5' } | Should -Throw '*exited with code 5*'
    }
}
