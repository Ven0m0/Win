#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  $script:ScriptPath = "$PSScriptRoot/../Scripts/Get-BedrockPackUpdate.ps1"
  $script:Section = [char]0x00A7
  $script:Slashes = [string][char]47 + [char]47

  # Manifest text that exercises every parsing hazard seen in the real pack folders: a leading
  # block comment, a trailing line comment, section-sign colour codes in the name, and a URL
  # inside a string value that must not be mistaken for a comment.
  function New-TestPack {
    param(
      [string]$Root,
      [string]$Kind,
      [string]$Folder,
      [string]$Uuid,
      [string]$Name
    )
    $dir = Join-Path -Path (Join-Path -Path $Root -ChildPath $Kind) -ChildPath $Folder
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $manifest = @"
/* Code by @Someone. https://example.com/ */
{
  "format_version": 2,
  "header": {
    "name": "$Name",
    "description": "see https://example.com/x",
    "uuid": "$Uuid",
    "version": [1, 0, 0]
  }
}
$script:Slashes
"@
    Set-Content -LiteralPath (Join-Path -Path $dir -ChildPath 'manifest.json') -Value $manifest
    $dir
  }
}

Describe 'Get-BedrockPackUpdate.ps1' {
  BeforeEach {
    $script:PackRoot = Join-Path $TestDrive ([guid]::NewGuid())
    # Only non-API URLs are used, so no test in this file reaches the network.
    $script:MapPath = Join-Path $script:PackRoot 'map.psd1'
    New-Item -ItemType Directory -Path $script:PackRoot -Force | Out-Null
  }

  Context 'Manifest parsing' {
    It 'Reads a JSONC manifest with block and line comments, stripping colour codes from the name' {
      New-TestPack -Root $PackRoot -Kind 'behavior_packs' -Folder 'a' `
        -Uuid '11111111-1111-1111-1111-111111111111' `
        -Name "$($script:Section)cCurse $($script:Section)7Pack" | Out-Null
      Set-Content -LiteralPath $MapPath -Value '@{}'

      $result = & $ScriptPath -PackRoot $PackRoot -SourceMap $MapPath -AsObject 6> $null

      $result.Count | Should -Be 1
      $result[0].Name | Should -Be 'Curse Pack'
      $result[0].Kind | Should -Be 'BP'
    }

    It 'Uses the manifest timestamp as the install date' {
      $dir = New-TestPack -Root $PackRoot -Kind 'resource_packs' -Folder 'b' `
        -Uuid '22222222-2222-2222-2222-222222222222' -Name 'Plain'
      $stamp = [datetime]'2024-03-04 05:06:07'
      (Get-Item -LiteralPath (Join-Path $dir 'manifest.json')).LastWriteTime = $stamp
      Set-Content -LiteralPath $MapPath -Value '@{}'

      $result = & $ScriptPath -PackRoot $PackRoot -SourceMap $MapPath -AsObject 6> $null

      $result[0].Installed | Should -Be $stamp
    }

    It 'Skips a pack with an unreadable manifest instead of aborting the run' {
      $dir = New-TestPack -Root $PackRoot -Kind 'behavior_packs' -Folder 'good' `
        -Uuid '33333333-3333-3333-3333-333333333333' -Name 'Good'
      $bad = Join-Path -Path (Join-Path $PackRoot 'behavior_packs') -ChildPath 'bad'
      New-Item -ItemType Directory -Path $bad -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $bad 'manifest.json') -Value '{ not json'
      Set-Content -LiteralPath $MapPath -Value '@{}'

      $result = & $ScriptPath -PackRoot $PackRoot -SourceMap $MapPath -AsObject 3> $null 6> $null

      $result.Count | Should -Be 1
      $result[0].Name | Should -Be 'Good'
      $dir | Should -Exist
    }
  }

  Context 'Source classification' {
    It 'Reports a pack with no map entry as UNMAPPED with a search URL' {
      New-TestPack -Root $PackRoot -Kind 'behavior_packs' -Folder 'a' `
        -Uuid '44444444-4444-4444-4444-444444444444' -Name 'Craftable Spawners' | Out-Null
      Set-Content -LiteralPath $MapPath -Value '@{}'

      $result = & $ScriptPath -PackRoot $PackRoot -SourceMap $MapPath -AsObject 6> $null

      $result[0].Status | Should -Be 'UNMAPPED'
      $result[0].Url | Should -BeLike '*curseforge.com/minecraft-bedrock/search*Craftable*'
    }

    It 'Reports a URL with no API behind it as CHECK, using the name from the map' {
      New-TestPack -Root $PackRoot -Kind 'resource_packs' -Folder 'a' `
        -Uuid '55555555-5555-5555-5555-555555555555' -Name 'pack.name' | Out-Null
      Set-Content -LiteralPath $MapPath -Value @"
@{
  '55555555-5555-5555-5555-555555555555' = @{ Name = 'Some Addon'; Url = 'https://mcpedl.com/some-addon/' }
}
"@

      $result = & $ScriptPath -PackRoot $PackRoot -SourceMap $MapPath -AsObject 6> $null

      $result[0].Status | Should -Be 'CHECK'
      $result[0].Name | Should -Be 'Some Addon'
      $result[0].Latest | Should -BeNullOrEmpty
    }

    It 'Warns and treats every pack as UNMAPPED when the source map is missing' {
      New-TestPack -Root $PackRoot -Kind 'behavior_packs' -Folder 'a' `
        -Uuid '66666666-6666-6666-6666-666666666666' -Name 'Orphan' | Out-Null

      $result = & $ScriptPath -PackRoot $PackRoot `
        -SourceMap (Join-Path $PackRoot 'absent.psd1') -AsObject 6> $null

      $result[0].Status | Should -Be 'UNMAPPED'
    }
  }

  Context 'Instance resolution' {
    It 'Picks the newest version-shaped instance directory' {
      $fakeAppData = Join-Path $TestDrive ([guid]::NewGuid())
      foreach ($v in '1.26.33.01', '1.26.40.05', '1.9.0.0', 'other') {
        $mojang = Join-Path -Path $fakeAppData `
          -ChildPath "levilauncher.exe\versions\$v\Minecraft Bedrock\Users\Shared\games\com.mojang"
        New-Item -ItemType Directory -Path (Join-Path $mojang 'behavior_packs') -Force | Out-Null
      }
      New-TestPack -Root (Join-Path -Path $fakeAppData `
          -ChildPath 'levilauncher.exe\versions\1.26.40.05\Minecraft Bedrock\Users\Shared\games\com.mojang') `
        -Kind 'behavior_packs' -Folder 'a' `
        -Uuid '77777777-7777-7777-7777-777777777777' -Name 'Newest' | Out-Null
      Set-Content -LiteralPath $MapPath -Value '@{}'

      $originalAppData = $env:APPDATA
      try {
        $env:APPDATA = $fakeAppData
        $result = & $ScriptPath -SourceMap $MapPath -AsObject 6> $null
      } finally {
        $env:APPDATA = $originalAppData
      }

      $result.Count | Should -Be 1
      $result[0].Name | Should -Be 'Newest'
    }

    It 'Throws a clear error for an instance that does not exist' {
      $fakeAppData = Join-Path $TestDrive ([guid]::NewGuid())
      New-Item -ItemType Directory -Path (Join-Path $fakeAppData 'levilauncher.exe\versions') -Force | Out-Null

      $originalAppData = $env:APPDATA
      try {
        $env:APPDATA = $fakeAppData
        { & $ScriptPath -Version '9.9.9.9' -SourceMap $MapPath 6> $null } |
          Should -Throw -ExpectedMessage "*9.9.9.9*"
      } finally {
        $env:APPDATA = $originalAppData
      }
    }
  }

  Context 'Read-only guarantee' {
    It 'Leaves every manifest untouched' {
      New-TestPack -Root $PackRoot -Kind 'behavior_packs' -Folder 'a' `
        -Uuid '88888888-8888-8888-8888-888888888888' -Name 'Untouched' | Out-Null
      Set-Content -LiteralPath $MapPath -Value '@{}'
      $before = Get-ChildItem -Path $PackRoot -Recurse -Filter 'manifest.json' |
        Select-Object FullName, LastWriteTime, Length

      & $ScriptPath -PackRoot $PackRoot -SourceMap $MapPath -AsObject 6> $null | Out-Null

      $after = Get-ChildItem -Path $PackRoot -Recurse -Filter 'manifest.json' |
        Select-Object FullName, LastWriteTime, Length
      Compare-Object $before $after -Property FullName, LastWriteTime, Length | Should -BeNullOrEmpty
    }
  }
}
