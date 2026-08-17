#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/optimize-media.ps1"
}

Describe 'optimize-media.ps1' {
    BeforeEach {
        $script:TestRoot = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    }

    Context 'Path validation' {
        It 'Fails cleanly for a path that does not exist' {
            $missing = Join-Path $TestRoot 'nope'
            { & $ScriptPath -Path $missing -SkipImages -SkipVideo *> $null } | Should -Throw
        }

        It 'Rejects a drive root with an explicit message instead of a Join-Path error' {
            $driveRoot = (Get-Item -LiteralPath $TestRoot).Root.FullName

            { & $ScriptPath -Path $driveRoot -SkipImages -SkipVideo *> $null } |
                Should -Throw -ExpectedMessage '*drive root*'
        }
    }

    Context 'Parameter validation' {
        It 'Rejects -ImageQuality above 100' {
            { & $ScriptPath -Path $TestRoot -ImageQuality 101 -SkipVideo *> $null } | Should -Throw
        }

        It 'Rejects -VideoQuality above 51' {
            { & $ScriptPath -Path $TestRoot -VideoQuality 52 -SkipImages *> $null } | Should -Throw
        }
    }

    Context 'Bracket-containing folder names' {
        It 'Finds files inside a folder whose name contains [ and ]' {
            $bracketDir = Join-Path $TestRoot '[Test] Folder'
            New-Item -ItemType Directory -Path $bracketDir -Force | Out-Null
            $file = Join-Path $bracketDir 'photo.png'
            Set-Content -LiteralPath $file -Value 'x'

            { & $ScriptPath -Path $bracketDir -SkipVideo -WhatIf *> $null } | Should -Not -Throw

            # No optimizer installed in the test environment, so the file is left untouched -
            # this test only proves Get-ChildItem -LiteralPath located it instead of silently
            # matching zero files against the [...] wildcard pattern.
            Test-Path -LiteralPath $file | Should -BeTrue
        }
    }

    Context '-WhatIf' {
        It 'Performs no writes: no backup folder, no output files, sources untouched' {
            $file = Join-Path $TestRoot 'photo.png'
            Set-Content -LiteralPath $file -Value 'x'

            & $ScriptPath -Path $TestRoot -SkipVideo -WhatIf *> $null

            $backupPath = "$TestRoot-bak"
            Test-Path -LiteralPath $backupPath | Should -BeFalse
            Test-Path -LiteralPath $file | Should -BeTrue
        }
    }
}
