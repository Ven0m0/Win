#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  $script:ScriptPath = "$PSScriptRoot/../Scripts/Get-BedrockPackUpdate.ps1"
  Add-Type -AssemblyName System.IO.Compression.FileSystem

  function New-PackFolder {
    param([string]$Dir, [string]$Uuid, [string]$Name, [string]$Type = 'data', [int[]]$Version = @(1, 0, 0))
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $manifest = @{
      format_version = 2
      header         = @{ name = $Name; uuid = $Uuid; version = $Version }
      modules        = @(@{ type = $Type; uuid = [guid]::NewGuid().ToString(); version = $Version })
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $Dir 'manifest.json') -Value $manifest
  }

  function New-Zip {
    param([string]$SourceDir, [string]$ZipPath)
    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDir, $ZipPath)
  }

  . $script:ScriptPath
}

Describe 'Get-BedrockPackUpdate.ps1 -Update' {
  BeforeEach {
    $script:Temp = Join-Path $TestDrive ([guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:Temp -Force | Out-Null
  }

  Context 'Add-PackSourceEntry' {
    It 'Appends an entry, keeps comments, and leaves a parseable map' {
      $map = Join-Path $Temp 'map.psd1'
      Set-Content -LiteralPath $map -Value "# keep me`n@{`n  'x' = @{ Name = 'X'; Url = 'https://x' }`n}`n"

      Add-PackSourceEntry -Path $map -Key 'new-key' -Name "O'Brien Pack" -Url 'https://github.com/a/b' |
        Should -BeTrue

      (Get-Content -LiteralPath $map -Raw) | Should -Match '# keep me'
      $loaded = Import-PowerShellDataFile -LiteralPath $map
      $loaded['new-key'].Name | Should -Be "O'Brien Pack"
      $loaded['x'].Url | Should -Be 'https://x'
    }

    It 'Does nothing for a key that is already mapped' {
      $map = Join-Path $Temp 'map.psd1'
      Set-Content -LiteralPath $map -Value "@{`n  'x' = @{ Name = 'X'; Url = 'https://x' }`n}`n"

      Add-PackSourceEntry -Path $map -Key 'x' -Name 'X' -Url 'https://y' | Should -BeFalse
    }
  }

  Context 'Expand-PackArchive' {
    It 'Unpacks a .mcaddon holding nested .mcpack files into a BP and an RP' {
      $bp = Join-Path $Temp 'src\bp'
      $rp = Join-Path $Temp 'src\rp'
      New-PackFolder -Dir $bp -Uuid '11111111-1111-1111-1111-111111111111' -Name 'Thing BP'
      New-PackFolder -Dir $rp -Uuid '22222222-2222-2222-2222-222222222222' -Name 'Thing RP' -Type 'resources'
      $stage = Join-Path $Temp 'stage'
      New-Item -ItemType Directory -Path $stage | Out-Null
      New-Zip -SourceDir $bp -ZipPath (Join-Path $stage 'bp.mcpack')
      New-Zip -SourceDir $rp -ZipPath (Join-Path $stage 'rp.mcpack')
      $addon = Join-Path $Temp 'thing.mcaddon'
      New-Zip -SourceDir $stage -ZipPath $addon

      $found = @(Expand-PackArchive -Path $addon -Destination (Join-Path $Temp 'work'))

      $found.Count | Should -Be 2
      ($found | Where-Object Uuid -eq '11111111-1111-1111-1111-111111111111').PackType | Should -Be 'BP'
      ($found | Where-Object Uuid -eq '22222222-2222-2222-2222-222222222222').PackType | Should -Be 'RP'
    }
  }

  Context 'Find-PackMatch' {
    It 'Prefers the same UUID, then the same type and name, and refuses ambiguity' {
      $cands = @(
        [pscustomobject]@{ Uuid = 'u1'; PackType = 'BP'; Name = 'Alpha'; Dir = 'd1'; Version = @(1) }
        [pscustomobject]@{ Uuid = 'u2'; PackType = 'BP'; Name = 'Beta'; Dir = 'd2'; Version = @(1) }
      )
      $byUuid = [pscustomobject]@{ Uuid = 'u2'; PackType = 'BP'; Name = 'zzz' }
      $byName = [pscustomobject]@{ Uuid = 'old'; PackType = 'BP'; Name = 'Alpha V2 (BP)' }
      $ambiguous = [pscustomobject]@{ Uuid = 'old'; PackType = 'BP'; Name = 'Gamma' }

      (Find-PackMatch -Installed $byUuid -Candidate $cands -GroupSize 2).Dir | Should -Be 'd2'
      (Find-PackMatch -Installed $byName -Candidate $cands -GroupSize 2).Dir | Should -Be 'd1'
      Find-PackMatch -Installed $ambiguous -Candidate $cands -GroupSize 2 | Should -BeNullOrEmpty
    }
  }

  Context 'Install-PackUpdate' {
    It 'Backs up the old pack, installs the new one, and stamps the manifest' {
      $old = Join-Path $Temp 'com.mojang\behavior_packs\abc'
      $new = Join-Path $Temp 'new'
      New-PackFolder -Dir $old -Uuid 'old' -Name 'Old'
      New-PackFolder -Dir $new -Uuid 'new' -Name 'New'
      (Get-Item (Join-Path $new 'manifest.json')).LastWriteTime = [datetime]'2020-01-01'
      $backup = Join-Path $Temp 'backup'

      Install-PackUpdate -OldPath $old -NewPath $new -BackupDir $backup

      (Get-Content (Join-Path $old 'manifest.json') -Raw) | Should -Match '"new"'
      (Join-Path $backup 'behavior_packs\abc\manifest.json') | Should -Exist
      (Get-Item (Join-Path $old 'manifest.json')).LastWriteTime | Should -BeGreaterThan (Get-Date).AddMinutes(-1)
    }

    It 'Changes nothing under -WhatIf' {
      $old = Join-Path $Temp 'com.mojang\behavior_packs\abc'
      $new = Join-Path $Temp 'new'
      New-PackFolder -Dir $old -Uuid 'old' -Name 'Old'
      New-PackFolder -Dir $new -Uuid 'new' -Name 'New'

      Install-PackUpdate -OldPath $old -NewPath $new -BackupDir (Join-Path $Temp 'backup') -WhatIf

      (Get-Content (Join-Path $old 'manifest.json') -Raw) | Should -Match '"old"'
      (Join-Path $Temp 'backup') | Should -Not -Exist
    }
  }

  Context 'Update-WorldPackReference' {
    It 'Repoints the matching entry, keeps a one-element list an array, and backs the file up' {
      $root = Join-Path $Temp 'com.mojang'
      $world = Join-Path $root 'minecraftWorlds\w1'
      New-Item -ItemType Directory -Path $world -Force | Out-Null
      $file = Join-Path $world 'world_behavior_packs.json'
      Set-Content -LiteralPath $file -Value '[ { "pack_id": "old", "version": [1, 0, 0] } ]'

      $count = Update-WorldPackReference -Root $root -OldUuid 'old' -NewUuid 'new' -NewVersion 2, 1, 0 `
        -BackupDir (Join-Path $Temp 'backup')

      $count | Should -Be 1
      $raw = (Get-Content -LiteralPath $file -Raw).Trim()
      $raw | Should -Match '^\['
      $parsed = @($raw | ConvertFrom-Json)
      $parsed[0].pack_id | Should -Be 'new'
      ($parsed[0].version -join '.') | Should -Be '2.1.0'
      (Join-Path $Temp 'backup\worlds\w1\world_behavior_packs.json') | Should -Exist
    }
  }
}
