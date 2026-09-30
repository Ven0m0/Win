#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# Top-level script; invoked with '&'. APPDATA/LOCALAPPDATA point at $TestDrive so profile discovery
# only ever sees fixture files, and sqlite3/Stop-Process are mocked.
Describe 'optimize-databases.ps1' {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/optimize-databases.ps1'
    $script:sqliteHeader = [Text.Encoding]::ASCII.GetBytes("SQLite format 3`0") + [byte[]](1..16)

    function sqlite3 { }
    $script:savedAppData = $env:APPDATA
    $script:savedLocalAppData = $env:LOCALAPPDATA
  }

  AfterAll {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
  }

  BeforeEach {
    $env:APPDATA = Join-Path -Path $TestDrive -ChildPath 'Roaming'
    $env:LOCALAPPDATA = Join-Path -Path $TestDrive -ChildPath 'Local'
    Remove-Item -Path "$TestDrive\*" -Recurse -Force -ErrorAction SilentlyContinue

    $floorpDir = Join-Path -Path $env:APPDATA -ChildPath 'Floorp\Profiles\abc'
    $null = New-Item -ItemType Directory -Path $floorpDir -Force
    [IO.File]::WriteAllBytes((Join-Path -Path $floorpDir -ChildPath 'places.sqlite'), $sqliteHeader)
    # Extensionless Chromium-style database: detected by header, not name.
    [IO.File]::WriteAllBytes((Join-Path -Path $floorpDir -ChildPath 'Cookies'), $sqliteHeader)
    Set-Content -Path (Join-Path -Path $floorpDir -ChildPath 'prefs.js') -Value 'user_pref("a", 1);'
    Set-Content -Path (Join-Path -Path $floorpDir -ChildPath 'fake.sqlite') -Value 'not a database'
    [IO.File]::WriteAllBytes((Join-Path -Path $floorpDir -ChildPath 'short.db'), [byte[]](83, 81, 76))

    $legcordDir = Join-Path -Path $env:APPDATA -ChildPath 'Legcord'
    $null = New-Item -ItemType Directory -Path $legcordDir -Force
    [IO.File]::WriteAllBytes((Join-Path -Path $legcordDir -ChildPath 'History'), $sqliteHeader)

    Mock sqlite3 { $global:LASTEXITCODE = 0 }
    Mock Get-Process { }
    Mock Stop-Process { }
    Mock Start-Sleep { }
    Mock Write-ColorOutput { }
    Mock Write-Warning { }
  }

  It 'Vacuums only files that carry the SQLite header' {
    & $scriptPath -App Floorp

    Should -Invoke sqlite3 -Times 2 -Exactly
    Should -Invoke sqlite3 -Times 1 -Exactly -ParameterFilter { $args[0] -like '*\places.sqlite' }
    Should -Invoke sqlite3 -Times 1 -Exactly -ParameterFilter { $args[0] -like '*\Cookies' }
    Should -Invoke sqlite3 -Times 2 -Exactly -ParameterFilter { $args[1] -eq 'PRAGMA optimize; VACUUM; ANALYZE;' }
  }

  It 'Processes every installed app by default and skips missing ones' {
    & $scriptPath

    # Floorp (2) + Legcord (1); Helium's directory does not exist.
    Should -Invoke sqlite3 -Times 3 -Exactly
    Should -Invoke sqlite3 -Times 1 -Exactly -ParameterFilter { $args[0] -like '*\Legcord\History' }
  }

  It 'Limits work to the apps passed with -App' {
    & $scriptPath -App Legcord

    Should -Invoke sqlite3 -Times 1 -Exactly
    Should -Invoke sqlite3 -Times 1 -Exactly -ParameterFilter { $args[0] -like '*\Legcord\History' }
  }

  It 'Stops a running app before vacuuming its databases' {
    Mock Get-Process -ParameterFilter { $Name -eq 'floorp' } { [Diagnostics.Process]::new() }

    & $scriptPath -App Floorp

    Should -Invoke Stop-Process -Times 1 -Exactly
  }

  It 'Neither stops apps nor vacuums under -WhatIf' {
    Mock Get-Process -ParameterFilter { $Name -eq 'floorp' } { [Diagnostics.Process]::new() }

    & $scriptPath -App Floorp -WhatIf

    Should -Invoke Stop-Process -Times 0
    Should -Invoke sqlite3 -Times 0
  }

  It 'Warns and continues when sqlite3 fails on a database' {
    Mock sqlite3 { $global:LASTEXITCODE = 5 }

    { & $scriptPath -App Floorp } | Should -Not -Throw

    Should -Invoke Write-Warning -Times 2 -Exactly -ParameterFilter { $Message -like '*Failed to optimize*' }
  }

  It 'Throws when sqlite3 is not on PATH' {
    Mock Get-Command -ParameterFilter { $Name -eq 'sqlite3' } { }

    { & $scriptPath -App Floorp } | Should -Throw '*sqlite3 not found*'
    Should -Invoke sqlite3 -Times 0
  }

  It 'Rejects unknown app names' {
    { & $scriptPath -App Chrome } | Should -Throw '*does not belong to the set*'
  }
}
