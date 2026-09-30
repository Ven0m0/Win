#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/invoke-ytdlp-download.ps1"
    . "$PSScriptRoot/../Scripts/Common.ps1"

    # Stubs for every external tool the script can call; each test mocks them so no
    # download, install, clone, or network call can happen.
    function yt-dlp { }
    function ffmpeg { }
    function spotdl { }
    function winget { }
    function uv { }

    # CmdletInfo captured before mocking; invoking it directly bypasses the mock alias.
    $script:RealGetCommand = Get-Command -Name Get-Command -CommandType Cmdlet
    $script:YtUrl = 'https://music.youtube.com/playlist?list=PLtest'

    function Get-ArgValue {
        param([object[]]$List, [string]$Flag)
        $i = [array]::IndexOf(@($List), $Flag)
        if ($i -ge 0) { $List[$i + 1] }
    }
}

Describe 'invoke-ytdlp-download.ps1' {
    BeforeEach {
        $script:OutRoot = Join-Path $TestDrive ([guid]::NewGuid())
        $script:NoCookies = Join-Path $TestDrive 'missing-cookies.txt'
        $script:Common = @{
            OutputDirectory = $OutRoot
            CookiesFile     = $NoCookies
            NoPotProvider   = $true
        }

        Mock Add-Log { }
        Mock Write-Warning { }
        Mock winget { }
        Mock uv { }
        Mock ffmpeg { }
        Mock spotdl { $global:LASTEXITCODE = 0 }
        Mock yt-dlp {
            $global:LASTEXITCODE = 0
            if ($args -contains '--print') { 'My Playlist: Vol. 1!' }
        }
    }

    Context 'Download command line' {
        It 'Builds a sanitized per-playlist folder and archive path' {
            & $ScriptPath -Url $YtUrl @Common

            $expectedDir = Join-Path $OutRoot 'my_playlist_vol_1'
            Test-Path -LiteralPath $expectedDir | Should -BeTrue
            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                $args -contains '-x' -and
                (Get-ArgValue $args '-P') -eq $expectedDir -and
                (Get-ArgValue $args '--download-archive') -eq (Join-Path $OutRoot 'my_playlist_vol_1.archive.txt') -and
                (Get-ArgValue $args '--audio-format') -eq 'mp3' -and
                $args[-1] -eq $YtUrl
            }
        }

        It 'Strips every SponsorBlock category except intro by default' {
            & $ScriptPath -Url $YtUrl @Common

            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                (Get-ArgValue $args '--sponsorblock-remove') -eq 'sponsor,outro,selfpromo,filler,interaction,music_offtopic'
            }
        }

        It '-NoSponsorBlock and -Format flac change the flags' {
            & $ScriptPath -Url $YtUrl @Common -NoSponsorBlock -Format flac

            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                $args -contains '-x' -and $args -notcontains '--sponsorblock-remove' -and
                (Get-ArgValue $args '--audio-format') -eq 'flac'
            }
        }

        It 'Rejects an unknown -Format' {
            { & $ScriptPath -Url $YtUrl @Common -Format wav } | Should -Throw
        }
    }

    Context '403 fallback' {
        It 'Retries once with player_client=web_safari and format 96 after a failed download' {
            $downloadCalls = @{ Count = 0 }
            Mock yt-dlp {
                $downloadCalls.Count++
                $global:LASTEXITCODE = if ($downloadCalls.Count -eq 1) { 1 } else { 0 }
            } -ParameterFilter { $args -contains '-x' }

            $result = & $ScriptPath -Url $YtUrl @Common -PassThrough

            Should -Invoke yt-dlp -Times 2 -Exactly -ParameterFilter { $args -contains '-x' }
            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                (Get-ArgValue $args '--extractor-args') -eq 'youtube:player_client=web_safari' -and
                (Get-ArgValue $args '-f') -eq '96/bestaudio/best'
            }
            $result.Status | Should -Be 'Completed'
        }

        It 'Does not retry when -PlayerClient is set, and reports the failure' {
            Mock yt-dlp { $global:LASTEXITCODE = 1 } -ParameterFilter { $args -contains '-x' }

            $result = & $ScriptPath -Url $YtUrl @Common -PlayerClient tv -PassThrough

            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                (Get-ArgValue $args '--extractor-args') -eq 'youtube:player_client=tv'
            }
            $result.Status | Should -Be 'Failed (exit 1)'
        }
    }

    Context 'Cookies' {
        It 'Uses a non-empty cookies.txt and drops it when validation fails' {
            $cookies = Join-Path $TestDrive 'cookies.txt'
            Set-Content -LiteralPath $cookies -Value '# Netscape HTTP Cookie File'
            Mock yt-dlp { $global:LASTEXITCODE = 1 } -ParameterFilter { $args -contains '--simulate' }

            & $ScriptPath -Url $YtUrl @Common -CookiesFile $cookies

            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                $args -contains '--simulate' -and (Get-ArgValue $args '--cookies') -eq $cookies -and
                (Get-ArgValue $args '--playlist-items') -eq '1'
            }
            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                $args -contains '-x' -and $args -notcontains '--cookies'
            }
        }

        It 'Maps -CookiesFromBrowser helium to the chrome extractor with the Helium profile path' {
            & $ScriptPath -Url $YtUrl @Common -CookiesFromBrowser helium

            $expected = 'chrome:' + (Join-Path $env:LOCALAPPDATA 'imput\Helium\User Data\Default')
            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                $args -contains '-x' -and (Get-ArgValue $args '--cookies-from-browser') -eq $expected
            }
        }
    }

    Context 'Spotify' {
        It 'Routes open.spotify.com URLs to spotdl, named after the saved list_name' {
            Mock spotdl {
                $global:LASTEXITCODE = 0
                $saveFile = Get-ArgValue $args '--save-file'
                '[{"list_name":"Road Trip","name":"Song"}]' | Set-Content -LiteralPath $saveFile
            } -ParameterFilter { $args[0] -eq 'save' }
            $spotifyUrl = 'https://open.spotify.com/playlist/abc'

            & $ScriptPath -Url $spotifyUrl @Common -Format flac

            Should -Invoke spotdl -Times 1 -Exactly -ParameterFilter {
                $args[0] -eq 'download' -and $args[1] -eq $spotifyUrl -and
                (Get-ArgValue $args '--format') -eq 'flac' -and
                (Get-ArgValue $args '--output') -like '*\road_trip\{track-number} - {title}.{output-ext}'
            }
            Should -Invoke yt-dlp -Times 0 -Exactly -ParameterFilter { $args -contains '-x' }
        }
    }

    Context 'Post-processing and safety' {
        It 'Lowercases and sanitizes downloaded file names' {
            Mock yt-dlp {
                $global:LASTEXITCODE = 0
                Set-Content -LiteralPath (Join-Path (Get-ArgValue $args '-P') 'Track One (Live).MP3') -Value 'x'
            } -ParameterFilter { $args -contains '-x' }

            & $ScriptPath -Url $YtUrl @Common

            $names = @(Get-ChildItem -LiteralPath (Join-Path $OutRoot 'my_playlist_vol_1') -File).Name
            $names | Should -Be @('track_one_live.mp3')
        }

        It 'Downloads every piped URL, not only the last one' {
            $secondUrl = 'https://music.youtube.com/playlist?list=PLsecond'

            $YtUrl, $secondUrl | & $ScriptPath @Common

            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter { $args -contains '-x' -and $args[-1] -eq $YtUrl }
            Should -Invoke yt-dlp -Times 1 -Exactly -ParameterFilter {
                $args -contains '-x' -and $args[-1] -eq $secondUrl
            }
        }

        It '-WhatIf downloads nothing' {
            & $ScriptPath -Url $YtUrl @Common -WhatIf

            Should -Invoke yt-dlp -Times 0 -Exactly -ParameterFilter { $args -contains '-x' }
        }

        It 'Tries winget for a missing dependency and stops when it is still missing' {
            # Pester 6 filtered mocks do not fall through; route other lookups to the real cmdlet.
            Mock Get-Command { & $RealGetCommand @PesterBoundParameters }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffmpeg' }

            & $ScriptPath -Url $YtUrl @Common

            Should -Invoke winget -Times 1 -Exactly -ParameterFilter {
                ($args -join ' ') -like 'install --id Gyan.FFmpeg -h*'
            }
            Should -Invoke yt-dlp -Times 0 -Exactly
        }
    }
}
