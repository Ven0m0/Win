#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/dedupe-media.ps1"
    # Dot-sourcing loads the functions without running the pipeline (InvocationName guard).
    . $script:ScriptPath

    # Writes a .cmd stand-in for an external tool. Every call is appended to <name>.log next to it.
    function New-StubTool {
        param([string]$Name, [string[]]$Body)
        $stub = Join-Path $TestDrive "$Name.cmd"
        $lines = @('@echo off', 'echo %* >> "%~dpn0.log"') + $Body
        [System.IO.File]::WriteAllText($stub, ($lines -join "`r`n") + "`r`n")
        $stub
    }

    function Get-StubCall {
        param([string]$Name)
        $log = Join-Path $TestDrive "$Name.log"
        if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log | ForEach-Object { $_.Trim() }) } else { @() }
    }
}

Describe 'Resolve-WritePolicy' {
    It 'Opt-in callers preview unless -Apply is given' {
        (Resolve-WritePolicy -OptIn).DryRun | Should -BeTrue
        (Resolve-WritePolicy -OptIn -Apply).DryRun | Should -BeFalse
    }

    It 'WhatIf wins over -Apply, and apply-by-default callers only preview under WhatIf' {
        (Resolve-WritePolicy -OptIn -Apply -WhatIfActive).DryRun | Should -BeTrue
        (Resolve-WritePolicy).DryRun | Should -BeFalse
        (Resolve-WritePolicy -WhatIfActive).DryRun | Should -BeTrue
    }

    It 'Flags a destination equal to or inside the scan root, but not a sibling' {
        $root = Join-Path $TestDrive 'scan'
        (Resolve-WritePolicy -ScanRoot $root -DestinationPath $root).DestinationInsideScanRoot | Should -BeTrue
        (Resolve-WritePolicy -ScanRoot $root -DestinationPath (Join-Path $root 'bak')).DestinationInsideScanRoot |
            Should -BeTrue
        (Resolve-WritePolicy -ScanRoot $root -DestinationPath "$root-bak").DestinationInsideScanRoot | Should -BeFalse
    }
}

Describe 'Invoke-ToolAboveNormal' {
    BeforeEach {
        Mock Write-Host { }
    }

    It 'Captures stdout lines and the exit code' {
        $tool = New-StubTool -Name 'say' -Body @('echo hello', 'exit /b 3')

        $result = Invoke-ToolAboveNormal -FilePath $tool -ArgumentList @('x')

        $result.Output | Should -Contain 'hello'
        $result.ExitCode | Should -Be 3
    }

    It 'Pipes -StandardInputPath to the process stdin' {
        $tool = New-StubTool -Name 'cat' -Body @('more')
        $in = Join-Path $TestDrive 'in.txt'
        Set-Content -LiteralPath $in -Value 'from-stdin'

        $result = Invoke-ToolAboveNormal -FilePath $tool -ArgumentList @('x') -StandardInputPath $in

        $result.Output | Should -Contain 'from-stdin'
    }
}

Describe 'dedupe-media.ps1' {
    BeforeEach {
        $script:OriginalTemp = $env:TEMP
        # The script writes its reports under $env:TEMP\dedupe-media.
        $env:TEMP = $TestDrive
        $script:Target = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
        Remove-Item -Path (Join-Path $TestDrive '*.log') -ErrorAction SilentlyContinue

        $script:Fclones = New-StubTool -Name 'fclones' -Body @(
            'if "%~1"=="group" if defined FAKE_GROUP_EXIT exit /b %FAKE_GROUP_EXIT%',
            'if "%~1"=="group" call :report %*',
            'if "%~1"=="remove" more > "%~dpn0.stdin"',
            'if "%~1"=="remove" if "%~2"=="--dry-run" (echo Would process 1 files and reclaim 100.0 KB space) else (echo Processed 1 files and reclaimed 100.0 KB space)',
            'exit /b 0',
            ':report',
            'if "%~1"=="--output" (echo report> "%~2" & exit /b 0)',
            'shift',
            'if not "%~1"=="" goto report',
            'exit /b 0'
        )
        $script:Czkawka = New-StubTool -Name 'czkawka_cli' -Body @(
            'echo Found 1 duplicated files which in 1 groups which takes 97.66 KiB.',
            'exit /b 0'
        )

        # Never install fclones/czkawka; the stubs stand in for the real tools.
        Mock Resolve-OrInstallTool { Join-Path $TestDrive ("$($Name[0]).cmd") }
        Mock Select-FolderDialog { throw 'folder picker must not open in tests' }
        Mock Write-Host { }
        Mock Format-Size { "$Bytes B" }
    }

    AfterEach {
        $env:TEMP = $script:OriginalTemp
        $env:FAKE_GROUP_EXIT = $null
    }

    Context 'Invoke-FclonesPass' {
        It 'Scopes group to media globs, case-insensitively, with excludes, and returns reclaimable bytes' {
            $bytes = Invoke-FclonesPass -Tool $Fclones -TargetPath $Target -NameGlob '*.jpg', '*.mkv' `
                -ExcludeGlob '**/private/**' -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $true

            $group = @(Get-StubCall 'fclones') | Where-Object { $_ -like 'group *' }
            $group | Should -BeLike '*--ignore-case*'
            $group | Should -BeLike '*--name *.jpg*'
            $group | Should -BeLike '*--exclude **/private/**'
            $group | Should -BeLike "* $Target*"
            $bytes | Should -Be 100000
        }

        It 'Adds --dry-run to remove only in preview' {
            $null = Invoke-FclonesPass -Tool $Fclones -TargetPath $Target -NameGlob '*.jpg' `
                -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $true
            Get-StubCall 'fclones' | Should -Contain 'remove --dry-run'
            # remove reads the group report on stdin
            (Get-Content -LiteralPath (Join-Path $TestDrive 'fclones.stdin') -Raw) | Should -BeLike 'report*'

            Remove-Item -Path (Join-Path $TestDrive 'fclones.log')
            $null = Invoke-FclonesPass -Tool $Fclones -TargetPath $Target -NameGlob '*.jpg' `
                -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $false
            Get-StubCall 'fclones' | Should -Contain 'remove'
        }

        It 'Throws when fclones group exits non-zero' {
            $env:FAKE_GROUP_EXIT = '2'

            { Invoke-FclonesPass -Tool $Fclones -TargetPath $Target -NameGlob '*.jpg' `
                    -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $true } |
                Should -Throw -ExpectedMessage '*fclones group failed (exit 2)*'
        }
    }

    Context 'Invoke-CzkawkaPass' {
        It 'Builds the image command line and converts the binary-unit summary to bytes' {
            $bytes = Invoke-CzkawkaPass -Tool $Czkawka -Mode image -TargetPath $Target -Threshold 12 `
                -MatchRotated -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $true

            $call = @(Get-StubCall 'czkawka_cli')[0]
            $call | Should -BeLike 'image *--max-difference 12*'
            $call | Should -BeLike '*Lanczos3*'
            $call | Should -BeLike '*mirror-flip-rotate90*'
            $call | Should -BeLike '*--dry-run*'
            [math]::Round($bytes) | Should -Be ([math]::Round(97.66 * 1024))
        }

        It 'Moves to the Recycle Bin (no --dry-run) when applying' {
            $null = Invoke-CzkawkaPass -Tool $Czkawka -Mode dup -TargetPath $Target `
                -AllowedExtensions 'jpg' -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $false

            $call = @(Get-StubCall 'czkawka_cli')[0]
            $call | Should -BeLike '*--move-to-trash*'
            $call | Should -Not -BeLike '*--dry-run*'
        }

        It 'Uses --delete-files for the empty-file pass instead of a keep-newest delete method' {
            $null = Invoke-CzkawkaPass -Tool $Czkawka -Mode empty-files -TargetPath $Target `
                -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $true

            $call = @(Get-StubCall 'czkawka_cli')[0]
            $call | Should -BeLike '*--delete-files*'
            $call | Should -Not -BeLike '*--delete-method*'
        }

        It 'Passes tolerance/window count to the video pass' {
            $null = Invoke-CzkawkaPass -Tool $Czkawka -Mode video -TargetPath $Target -Threshold 3 -WindowCount 8 `
                -CheckAudio -ReportPath (Join-Path $TestDrive 'r.txt') -DryRun $true

            $call = @(Get-StubCall 'czkawka_cli')[0]
            $call | Should -BeLike 'video *--tolerance 3*--window-count 8*'
            $call | Should -BeLike '*--check-audio-content*'
        }
    }

    Context 'Preview vs apply (script entry)' {
        It 'Previews by default: fclones and every czkawka pass get --dry-run, nothing moved to trash' {
            & $ScriptPath -Path $Target

            Get-StubCall 'fclones' | Should -Contain 'remove --dry-run'
            $czkawka = @(Get-StubCall 'czkawka_cli')
            $czkawka.Count | Should -Be 3
            foreach ($call in $czkawka) {
                $call | Should -BeLike '*--dry-run*'
                $call | Should -Not -BeLike '*--move-to-trash*'
            }
        }

        It '-Apply -Force deletes exact dups and sends fuzzy matches to the Recycle Bin' {
            & $ScriptPath -Path $Target -Apply -Force

            Get-StubCall 'fclones' | Should -Contain 'remove'
            Get-StubCall 'fclones' | Should -Not -Contain 'remove --dry-run'
            $czkawka = @(Get-StubCall 'czkawka_cli')
            $czkawka.Count | Should -Be 3
            foreach ($call in $czkawka) {
                $call | Should -BeLike '*--move-to-trash*'
                $call | Should -Not -BeLike '*--dry-run*'
            }
        }

        It '-WhatIf forces preview even with -Apply (no writes)' {
            & $ScriptPath -Path $Target -Apply -WhatIf

            Get-StubCall 'fclones' | Should -Contain 'remove --dry-run'
            @(Get-StubCall 'czkawka_cli' | Where-Object { $_ -like '*--move-to-trash*' }).Count | Should -Be 0
        }
    }

    Context 'Pass selection' {
        It 'Skips the czkawka dup pass unless -IncludeDup is given' {
            & $ScriptPath -Path $Target
            @(Get-StubCall 'czkawka_cli' | Where-Object { $_ -like 'dup *' }).Count | Should -Be 0

            & $ScriptPath -Path $Target -IncludeDup
            @(Get-StubCall 'czkawka_cli' | Where-Object { $_ -like 'dup *' }).Count | Should -Be 1
        }

        It 'Does not resolve (or install) czkawka when every czkawka pass is skipped' {
            & $ScriptPath -Path $Target -SkipImages -SkipVideos -SkipEmptyFiles

            Should -Invoke Resolve-OrInstallTool -Times 1 -Exactly
            Should -Invoke Resolve-OrInstallTool -Times 0 -Exactly -ParameterFilter { $Name -contains 'czkawka_cli' }
        }
    }

    Context 'Script-level behavior' {
        It 'Rejects a path that is a file, not a folder' {
            $file = Join-Path $Target 'a.jpg'
            Set-Content -LiteralPath $file -Value 'x'

            { & $ScriptPath -Path $file } | Should -Throw -ExpectedMessage '*not a folder*'
        }

        It 'Rejects -ImageDifference above 40' {
            { & $ScriptPath -Path $Target -ImageDifference 41 } | Should -Throw
        }

        It 'Treats a literal --help as a help request and runs no tools' {
            $null = & $ScriptPath '--help'

            Get-StubCall 'fclones' | Should -BeNullOrEmpty
            Should -Invoke Resolve-OrInstallTool -Times 0 -Exactly
        }
    }
}
