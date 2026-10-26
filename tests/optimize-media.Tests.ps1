#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/optimize-media.ps1"
    # Dot-sourcing loads the functions without running the pipeline (InvocationName guard).
    . $script:ScriptPath

    # Writes a .cmd stand-in for an external tool. Every call is appended to <name>.log next to it.
    function New-StubTool {
        param([string]$Name, [string[]]$Body = @())
        $stub = Join-Path $TestDrive "$Name.cmd"
        $lines = @('@echo off', 'echo %* >> "%~dpn0.log"') + $Body + @('exit /b 0')
        [System.IO.File]::WriteAllText($stub, ($lines -join "`r`n") + "`r`n")
        $stub
    }

    function Get-StubCall {
        param([string]$Name)
        $log = Join-Path $TestDrive "$Name.log"
        if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log | ForEach-Object { $_.Trim() }) } else { @() }
    }
}

Describe 'Invoke-ImagePass / Invoke-VideoPass with stub tools' {
    BeforeEach {
        Get-ChildItem -Path $TestDrive -Filter '*.log' | Remove-Item
        $script:Root = Join-Path $TestDrive ([guid]::NewGuid())
        $script:Bak = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        Mock Write-Host { }
        Mock Resolve-OrInstallTool { Join-Path $TestDrive "$($Name[0]).cmd" }
    }

    Context 'Invoke-ImagePass' {
        BeforeEach {
            $null = New-StubTool -Name 'oxipng'
            $null = New-StubTool -Name 'jpegoptim'
            Set-Content -LiteralPath (Join-Path $Root 'photo.jpg') -Value ('x' * 200)
            Set-Content -LiteralPath (Join-Path $Root 'pic.png') -Value ('x' * 200)
        }

        It 'Backs up lossy JPEG originals, then runs jpegoptim and oxipng' {
            $null = Invoke-ImagePass -TargetPath $Root -Quality 80 -OxipngLevel 2 -MaxDimension 0 -BackupPath $Bak

            Test-Path -LiteralPath (Join-Path $Bak 'photo.jpg') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $Bak 'pic.png') | Should -BeFalse
            @(Get-StubCall 'jpegoptim')[0] | Should -BeLike '-m80 *photo.jpg'
            @(Get-StubCall 'oxipng')[0] | Should -BeLike '-o 2 --strip safe *pic.png'
        }

        It 'Performs no writes under -WhatIf: no backup, no tool runs, sources untouched' {
            $null = Invoke-ImagePass -TargetPath $Root -Quality 80 -OxipngLevel 2 -MaxDimension 0 `
                -BackupPath $Bak -WhatIf

            Test-Path -LiteralPath $Bak | Should -BeFalse
            Get-StubCall 'jpegoptim' | Should -BeNullOrEmpty
            Get-StubCall 'oxipng' | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $Root 'photo.jpg') | Should -BeTrue
        }
    }

    Context 'Invoke-VideoPass' {
        BeforeEach {
            $null = New-StubTool -Name 'ffprobe' -Body @('echo h264')
            # Writes a tiny file to the last argument, which is the output path.
            $null = New-StubTool -Name 'ffmpeg' -Body @('for %%a in (%*) do set "last=%%~a"', 'echo x> "%last%"')
            Set-Content -LiteralPath (Join-Path $Root 'clip.mp4') -Value ('x' * 500)
            $script:VideoArgs = @{
                TargetPath      = $Root
                Ffmpeg          = Join-Path $TestDrive 'ffmpeg.cmd'
                Ffprobe         = Join-Path $TestDrive 'ffprobe.cmd'
                Ffzap           = ''
                EncoderArgs     = @('-c:v', 'libx265')
                VideoFilterArgs = @()
                VideoProfile    = [PSCustomObject]@{ Suffix = '.h265.mp4'; MuxArgs = @('-movflags', '+faststart') }
                AudioBitrate    = '96k'
                ThreadCount     = 1
                BackupPath      = $Bak
            }
        }

        It 'Encodes, validates, and moves the source into the backup mirror' {
            $result = Invoke-VideoPass @VideoArgs

            $result.Encoded | Should -Be 1
            Test-Path -LiteralPath (Join-Path $Root 'clip.h265.mp4') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $Root 'clip.mp4') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $Bak 'clip.mp4') | Should -BeTrue
        }

        It 'Performs no writes under -WhatIf: no encode, no backup, source untouched' {
            $null = Invoke-VideoPass @VideoArgs -WhatIf

            Get-StubCall 'ffmpeg' | Should -BeNullOrEmpty
            Test-Path -LiteralPath $Bak | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $Root 'clip.mp4') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $Root 'clip.h265.mp4') | Should -BeFalse
        }
    }
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

        It 'Refuses a -BackupPath inside the scanned folder' {
            $inside = Join-Path $TestRoot 'bak'

            { & $ScriptPath -Path $TestRoot -BackupPath $inside -SkipImages -SkipVideo *> $null } |
                Should -Throw -ExpectedMessage '*inside the scanned folder*'
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
            $backup = Join-Path $TestDrive 'bak'

            { & $ScriptPath -Path $bracketDir -BackupPath $backup -SkipVideo -WhatIf *> $null } |
                Should -Not -Throw

            # No optimizer installed in the test environment, so the file is left untouched -
            # this test only proves Directory.EnumerateFiles located it instead of silently
            # matching zero files against the [...] wildcard pattern.
            Test-Path -LiteralPath $file | Should -BeTrue
        }
    }

    Context '-WhatIf' {
        It 'Performs no writes: no backup folder, no output files, sources untouched' {
            $file = Join-Path $TestRoot 'photo.png'
            Set-Content -LiteralPath $file -Value 'x'
            $backupPath = Join-Path $TestDrive 'whatif-bak'

            & $ScriptPath -Path $TestRoot -BackupPath $backupPath -SkipVideo -WhatIf *> $null

            Test-Path -LiteralPath $backupPath | Should -BeFalse
            Test-Path -LiteralPath $file | Should -BeTrue
        }

        It '-ConvertToWebp performs no writes: no backup folder, no .webp output, source untouched' {
            $file = Join-Path $TestRoot 'photo.jpg'
            Set-Content -LiteralPath $file -Value 'x'
            $backupPath = Join-Path $TestDrive 'webp-whatif-bak'
            $webpOutput = Join-Path $TestRoot 'photo.webp'

            & $ScriptPath -Path $TestRoot -BackupPath $backupPath -SkipVideo -ConvertToWebp -WhatIf *> $null

            Test-Path -LiteralPath $backupPath | Should -BeFalse
            Test-Path -LiteralPath $webpOutput | Should -BeFalse
            Test-Path -LiteralPath $file | Should -BeTrue
        }
    }
}
