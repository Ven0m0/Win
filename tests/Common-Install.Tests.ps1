#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/Common.ps1"
    # Stub so Pester can mock it; nothing real is ever invoked.
    function winget { param([Parameter(ValueFromRemainingArguments)]$Rest) }
}

Describe "Install-WingetTool" {
    BeforeEach {
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Wait-ForWinget { 'winget' }
        Mock Update-EnvironmentPath { }
        $script:wingetExit = 0
        Mock winget { $global:LASTEXITCODE = $script:wingetExit }
    }

    It "Accepts <Code> as success and refreshes PATH" -ForEach @(
        @{ Code = 0 }, @{ Code = -1978335189 }, @{ Code = -1978335230 }
    ) {
        $script:wingetExit = $Code

        Install-WingetTool -Id 'Git.Git' -Name 'Git'

        Should -Invoke winget -Times 1 -Exactly
        Should -Invoke Update-EnvironmentPath -Times 1 -Exactly
        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It "Warns on any other exit code" {
        $script:wingetExit = 1

        Install-WingetTool -Id 'Git.Git' -Name 'Git'

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*exit code: 1*' }
        Should -Invoke Update-EnvironmentPath -Times 0 -Exactly
    }

    It "Does not call winget under -WhatIf" {
        Install-WingetTool -Id 'Git.Git' -Name 'Git' -WhatIf

        Should -Invoke winget -Times 0 -Exactly
    }
}

Describe "Get-GitHubReleaseAsset" {
    BeforeEach {
        Mock Get-GitHubRelease {
            [pscustomobject]@{
                tag_name     = 'v1.2.3'
                published_at = '2026-01-02T03:04:05Z'
                assets       = @(
                    [pscustomobject]@{ name = 'tool-x64.msi'; browser_download_url = 'https://example.test/x64.msi' }
                    [pscustomobject]@{ name = 'tool-installer.exe'; browser_download_url = 'https://example.test/i.exe' }
                )
            }
        }
    }

    It "Finds an asset by exact name" {
        $asset = Get-GitHubReleaseAsset -Repository 'o/r' -ExactName 'tool-installer.exe'

        $asset.BrowserDownloadUrl | Should -Be 'https://example.test/i.exe'
        $asset.ReleaseTag | Should -Be 'v1.2.3'
    }

    It "Finds an asset by wildcard pattern" {
        (Get-GitHubReleaseAsset -Repository 'o/r' -AssetPattern '*.msi').Name | Should -Be 'tool-x64.msi'
    }

    It "Throws when no asset matches" {
        { Get-GitHubReleaseAsset -Repository 'o/r' -ExactName 'missing.exe' } |
            Should -Throw '*Could not find matching release asset*'
    }
}
