#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/dedupe-media.ps1"
    . "$PSScriptRoot/../Scripts/Common.ps1"

    # Defined inside dedupe-media.ps1; stubbed here so Pester can build a mock for it.
    # The mock alias takes precedence over the script's own definition when it runs.
    function Invoke-ToolAboveNormal {
        param($FilePath, $ArgumentList, $StandardInputPath, [switch]$WatchFfmpeg)
    }
}

Describe 'dedupe-media.ps1' {
    BeforeEach {
        $script:OriginalTemp = $env:TEMP
        # The script writes its reports under $env:TEMP\dedupe-media.
        $env:TEMP = $TestDrive
        $script:Target = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $Target -Force | Out-Null

        # Never install fclones/czkawka; paths point at nothing so a leaked call fails harmlessly.
        Mock Resolve-OrInstallTool { Join-Path $TestDrive "$($Name[0]).exe" }
        Mock Select-FolderDialog { throw 'folder picker must not open in tests' }
        Mock Write-Host { }
        Mock Format-Size { "$Bytes B" }
        Mock Invoke-ToolAboveNormal {
            [pscustomobject]@{
                Output   = @('Would process 1 files and reclaim 100.0 KB space')
                ExitCode = 0
            }
        }
    }

    AfterEach {
        $env:TEMP = $script:OriginalTemp
    }

    Context 'Preview vs apply' {
        It 'Previews by default: fclones and every czkawka pass get --dry-run, nothing moved to trash' {
            & $ScriptPath -Path $Target

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $ArgumentList[0] -eq 'remove' -and $ArgumentList -contains '--dry-run'
            }
            Should -Invoke Invoke-ToolAboveNormal -Times 3 -Exactly -ParameterFilter {
                $ArgumentList[0] -in 'image', 'video', 'empty-files' -and
                $ArgumentList -contains '--dry-run' -and $ArgumentList -notcontains '--move-to-trash'
            }
        }

        It '-Apply -Force deletes exact dups and sends fuzzy matches to the Recycle Bin' {
            & $ScriptPath -Path $Target -Apply -Force

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $ArgumentList[0] -eq 'remove' -and $ArgumentList -notcontains '--dry-run'
            }
            Should -Invoke Invoke-ToolAboveNormal -Times 3 -Exactly -ParameterFilter {
                $ArgumentList -contains '--move-to-trash' -and $ArgumentList -notcontains '--dry-run'
            }
        }

        It '-WhatIf forces preview even with -Apply' {
            & $ScriptPath -Path $Target -Apply -WhatIf

            Should -Invoke Invoke-ToolAboveNormal -Times 0 -Exactly -ParameterFilter {
                $ArgumentList -contains '--move-to-trash'
            }
            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $ArgumentList[0] -eq 'remove' -and $ArgumentList -contains '--dry-run'
            }
        }
    }

    Context 'Pass selection' {
        It 'Skips the czkawka dup pass unless -IncludeDup is given' {
            & $ScriptPath -Path $Target
            Should -Invoke Invoke-ToolAboveNormal -Times 0 -Exactly -ParameterFilter { $ArgumentList[0] -eq 'dup' }

            & $ScriptPath -Path $Target -IncludeDup
            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter { $ArgumentList[0] -eq 'dup' }
        }

        It 'Does not resolve (or install) czkawka when every czkawka pass is skipped' {
            & $ScriptPath -Path $Target -SkipImages -SkipVideos -SkipEmptyFiles

            Should -Invoke Resolve-OrInstallTool -Times 1 -Exactly
            Should -Invoke Resolve-OrInstallTool -Times 0 -Exactly -ParameterFilter { $Name -contains 'czkawka_cli' }
        }
    }

    Context 'Command-line construction' {
        It 'Scopes fclones group to media globs, case-insensitively, with built-in and user excludes' {
            & $ScriptPath -Path $Target -SkipImages -SkipVideos -SkipEmptyFiles -Exclude '**/private/**'

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $a = @($ArgumentList)
                $a[0] -eq 'group' -and
                $a -contains '--ignore-case' -and
                $a -contains '*.jpg' -and $a -contains '*.mkv' -and
                $a -contains '**/files_versions/**' -and
                $a -contains '**/private/**' -and
                $a[-1] -eq $Target
            }
        }

        It 'Feeds the fclones group report to remove via stdin' {
            & $ScriptPath -Path $Target -SkipImages -SkipVideos -SkipEmptyFiles

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $ArgumentList[0] -eq 'remove' -and $StandardInputPath -like '*fclones-*.txt'
            }
        }

        It 'Adds rotation matching and Lanczos3 to the image pass only when asked' {
            & $ScriptPath -Path $Target -SkipExact -SkipVideos -SkipEmptyFiles -ImageDifference 12 -MatchRotated

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $a = @($ArgumentList)
                $i = [array]::IndexOf($a, '--max-difference')
                $a[0] -eq 'image' -and $a[$i + 1] -eq '12' -and
                $a -contains 'Lanczos3' -and $a -contains 'mirror-flip-rotate90' -and
                $a -contains '--minimal-file-size' -and -not $WatchFfmpeg
            }
        }

        It 'Passes tolerance/window count to the video pass and watches its ffmpeg children' {
            & $ScriptPath -Path $Target -SkipExact -SkipImages -SkipEmptyFiles -VideoTolerance 3 -CheckAudio

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $a = @($ArgumentList)
                $a[0] -eq 'video' -and
                $a[[array]::IndexOf($a, '--tolerance') + 1] -eq '3' -and
                $a[[array]::IndexOf($a, '--window-count') + 1] -eq '8' -and
                $a -contains '--check-audio-content' -and $WatchFfmpeg
            }
        }

        It 'Uses --delete-files for the empty-file pass instead of a keep-newest delete method' {
            & $ScriptPath -Path $Target -SkipExact -SkipImages -SkipVideos

            Should -Invoke Invoke-ToolAboveNormal -Times 1 -Exactly -ParameterFilter {
                $ArgumentList[0] -eq 'empty-files' -and
                $ArgumentList -contains '--delete-files' -and $ArgumentList -notcontains '--delete-method'
            }
        }
    }

    Context 'Results and errors' {
        It 'Converts the fclones decimal "reclaim 100.0 KB" summary to bytes' {
            & $ScriptPath -Path $Target -SkipImages -SkipVideos -SkipEmptyFiles

            Should -Invoke Format-Size -Times 1 -Exactly -ParameterFilter { $Bytes -eq 100000 }
        }

        It 'Throws when fclones group exits non-zero' {
            Mock Invoke-ToolAboveNormal { [pscustomobject]@{ Output = @(); ExitCode = 2 } } -ParameterFilter {
                $ArgumentList[0] -eq 'group'
            }

            { & $ScriptPath -Path $Target } | Should -Throw -ExpectedMessage '*fclones group failed (exit 2)*'
        }

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

            Should -Invoke Invoke-ToolAboveNormal -Times 0 -Exactly
            Should -Invoke Resolve-OrInstallTool -Times 0 -Exactly
        }
    }
}
