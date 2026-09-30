#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/invoke-imgburn-audio.ps1"
    . "$PSScriptRoot/../Scripts/Common.ps1"

    # ffmpeg is invoked by the path Get-Command returns; returning this stub's name routes
    # every transcode to the mock below instead of a real ffmpeg.
    function ffmpeg-stub { }

    # CmdletInfos captured before mocking; invoking them directly bypasses the mock alias,
    # so filtered mocks below can fall back to the real (read-only) cmdlets.
    $script:RealTestPath = Get-Command -Name Test-Path -CommandType Cmdlet
    $script:RealGetCommand = Get-Command -Name Get-Command -CommandType Cmdlet

    # Fake IMAPI2 COM objects. Media state is read from $Disc, set per test.
    function New-FakeImapiObject {
        param([string]$ComObject)
        switch ($ComObject) {
            'IMAPI2.MsftDiscMaster2' { , @('recorder-1') }
            'IMAPI2.MsftDiscRecorder2' {
                $rec = [pscustomobject]@{ VolumePathNames = @('E:\') }
                $rec | Add-Member -MemberType ScriptMethod -Name InitializeDiscRecorder -Value { param($RecorderId) }
                $rec
            }
            'IMAPI2.MsftDiscFormat2Data' {
                [pscustomobject]@{
                    Recorder                 = $null
                    MediaHeuristicallyBlank  = $Disc.Blank
                    CurrentPhysicalMediaType = $Disc.MediaType
                }
            }
            'IMAPI2.MsftDiscFormat2Erase' {
                $eraser = [pscustomobject]@{ Recorder = $null }
                $eraser | Add-Member -MemberType ScriptMethod -Name EraseMedia -Value { $Disc.Erased = $true }
                $eraser
            }
        }
    }

    function Get-ArgValue {
        param([object[]]$List, [string]$Flag)
        $i = [array]::IndexOf(@($List), $Flag)
        if ($i -ge 0) { $List[$i + 1] }
    }
}

Describe 'invoke-imgburn-audio.ps1' {
    BeforeEach {
        $script:OriginalTemp = $env:TEMP
        $env:TEMP = Join-Path $TestDrive 'temp'
        $null = New-Item -ItemType Directory -Path $env:TEMP -Force

        $script:Source = Join-Path $TestDrive "album-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
        $null = New-Item -ItemType Directory -Path $Source -Force
        foreach ($name in '01 intro.flac', '02 song.mp3', 'cover.jpg') {
            Set-Content -LiteralPath (Join-Path $Source $name) -Value 'x'
        }

        $Disc = @{ Blank = $true; MediaType = 2; Erased = $false }
        $Burn = @{ Cue = $null; ExitCode = 0 }

        Mock Add-Log { }
        Mock Write-Warning { }
        Mock Test-Path { & $RealTestPath @PesterBoundParameters }
        Mock Get-Command { & $RealGetCommand @PesterBoundParameters }
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like '*\ImgBurn\ImgBurn.exe' }
        Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like '*\ImgBurn\ImgBurn64.exe' }
        Mock Get-Command { [pscustomobject]@{ Source = 'ffmpeg-stub' } } -ParameterFilter { $Name -eq 'ffmpeg.exe' }
        Mock Get-CimInstance { [pscustomobject]@{ Drive = 'E:'; MediaType = 'CD-ROM'; Name = 'Fake CD Writer' } }
        Mock New-Object { New-FakeImapiObject -ComObject $ComObject } -ParameterFilter { $ComObject -like 'IMAPI2.*' }
        Mock Get-Process { } -ParameterFilter { $Name -eq 'ImgBurn' }
        Mock Stop-Process { }
        # Transcode like ffmpeg would: fail if the output folder is missing, else write the
        # output file (last argument). -WhatIf:$false because a real ffmpeg ignores -WhatIf.
        Mock ffmpeg-stub {
            $flat = @($args | ForEach-Object { $_ })
            if (-not (& $RealTestPath -LiteralPath (Split-Path -Parent $flat[-1]))) {
                $global:LASTEXITCODE = 1
                return
            }
            Set-Content -LiteralPath $flat[-1] -Value 'pcm' -WhatIf:$false
            $global:LASTEXITCODE = 0
        }
        Mock Start-Process {
            $src = Get-ArgValue $ArgumentList '/SRC'
            if ($src -like '*.cue') { $Burn.Cue = Get-Content -LiteralPath $src }
            [pscustomobject]@{ ExitCode = $Burn.ExitCode }
        }
    }

    AfterEach {
        $env:TEMP = $script:OriginalTemp
    }

    Context 'Audio CD (default)' {
        It 'Transcodes to CD-DA WAV and burns a CUE with one track per audio file' {
            & $ScriptPath -Path $Source

            Should -Invoke ffmpeg-stub -Times 2 -Exactly -ParameterFilter {
                $flat = @($args | ForEach-Object { $_ })
                (Get-ArgValue $flat '-ar') -eq '44100' -and (Get-ArgValue $flat '-sample_fmt') -eq 's16'
            }
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -like '*ImgBurn.exe' -and $Wait -and
                (Get-ArgValue $ArgumentList '/MODE') -eq 'WRITE' -and
                (Get-ArgValue $ArgumentList '/DEST') -eq 'E:' -and
                (Get-ArgValue $ArgumentList '/SPEED') -eq '8' -and
                (Get-ArgValue $ArgumentList '/WRITETYPE') -eq 'DAO' -and
                $ArgumentList -notcontains '/EJECT'
            }
            @($Burn.Cue | Where-Object { $_ -match '^\s*TRACK \d\d AUDIO$' }).Count | Should -Be 2
            @($Burn.Cue | Where-Object { $_ -match '^FILE ".*track_0[12]\.wav" WAVE$' }).Count | Should -Be 2
        }

        It 'Deletes the temporary WAV/CUE folder after the burn' {
            & $ScriptPath -Path $Source

            @(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'imgburn_*').Count | Should -Be 0
        }

        It 'Appends /EJECT and /VERIFY and forwards -Speed/-WriteType' {
            & $ScriptPath -Path $Source -Eject -Verify -Speed 4 -WriteType SAO

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '/EJECT' -and $ArgumentList -contains '/VERIFY' -and
                (Get-ArgValue $ArgumentList '/SPEED') -eq '4' -and
                (Get-ArgValue $ArgumentList '/WRITETYPE') -eq 'SAO'
            }
        }

        It 'Emits a result object with the ImgBurn exit code under -PassThrough' {
            $Burn.ExitCode = 5

            $result = & $ScriptPath -Path $Source -PassThrough

            $result.Status | Should -Be 'Failed (exit 5)'
            $result.Drive | Should -Be 'E:'
        }

        It '-WhatIf neither erases nor burns' {
            $Disc.Blank = $false
            $Disc.MediaType = 3

            { & $ScriptPath -Path $Source -WhatIf } | Should -Not -Throw

            $Disc.Erased | Should -BeFalse
            Should -Invoke ffmpeg-stub -Times 0 -Exactly
            Should -Invoke Start-Process -Times 0 -Exactly
            Should -Invoke Stop-Process -Times 0 -Exactly
        }
    }

    Context 'MP3 data CD' {
        It 'Copies existing MP3s, transcodes the rest to 320k, and builds an ISO9660+Joliet disc' {
            & $ScriptPath -Path $Source -DataCd

            $mp3Dir = "${Source}_mp3"
            @(Get-ChildItem -LiteralPath $mp3Dir -File).Name | Sort-Object | Should -Be @('01 intro.mp3', '02 song.mp3')
            Should -Invoke ffmpeg-stub -Times 1 -Exactly -ParameterFilter {
                $flat = @($args | ForEach-Object { $_ })
                (Get-ArgValue $flat '-c:a') -eq 'libmp3lame' -and (Get-ArgValue $flat '-b:a') -eq '320k'
            }
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                (Get-ArgValue $ArgumentList '/MODE') -eq 'BUILD' -and
                (Get-ArgValue $ArgumentList '/SRC') -eq $mp3Dir -and
                (Get-ArgValue $ArgumentList '/FILESYSTEM') -eq 'ISO9660 + Joliet'
            }
        }

        It 'Re-encodes MP3 sources too with -Reencode' {
            & $ScriptPath -Path $Source -DataCd -Reencode

            Should -Invoke ffmpeg-stub -Times 2 -Exactly
        }

        It 'Sanitizes the volume label to 16 uppercase ISO9660 characters' {
            $long = Join-Path $TestDrive 'My Road-Trip Mix 2026!'
            $null = New-Item -ItemType Directory -Path $long -Force
            Set-Content -LiteralPath (Join-Path $long 'a.flac') -Value 'x'

            & $ScriptPath -Path $long -DataCd

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                (Get-ArgValue $ArgumentList '/VOLUMELABEL_ISO9660') -eq 'MY_ROAD_TRIP_MIX'
            }
        }
    }

    Context 'Disc and drive checks' {
        It 'Erases a non-blank rewritable disc before burning' {
            $Disc.Blank = $false
            $Disc.MediaType = 3

            & $ScriptPath -Path $Source

            $Disc.Erased | Should -BeTrue
            Should -Invoke Start-Process -Times 1 -Exactly
        }

        It 'Refuses a non-blank, non-rewritable disc' {
            $Disc.Blank = $false
            $Disc.MediaType = 2

            { & $ScriptPath -Path $Source } | Should -Throw -ExpectedMessage '*not blank and is not a rewritable*'
            $Disc.Erased | Should -BeFalse
            Should -Invoke Start-Process -Times 0 -Exactly
        }

        It 'Fails when -DriveLetter is not an optical drive' {
            { & $ScriptPath -Path $Source -DriveLetter F } |
                Should -Throw -ExpectedMessage "*Drive 'F' not found*"
        }

        It 'Fails and cleans up when ffmpeg cannot transcode a track' {
            Mock ffmpeg-stub { $global:LASTEXITCODE = 1 }

            { & $ScriptPath -Path $Source } | Should -Throw -ExpectedMessage '*ffmpeg failed to transcode*'
            @(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'imgburn_*').Count | Should -Be 0
            Should -Invoke Start-Process -Times 0 -Exactly
        }

        It 'Rejects -Speed above 48' {
            { & $ScriptPath -Path $Source -Speed 49 } | Should -Throw
        }
    }
}
