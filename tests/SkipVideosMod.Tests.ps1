#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/arc-raiders/SkipVideosMod.ps1"
}

Describe "SkipVideosMod Script Initialization" {
    It "Should safely source the script" {
        $true | Should -Be $true
    }

    It "Should export the expected functions" {
        $expectedFunctions = @(
            "Find-ArcRaider",
            "Remove-VideoFile",
            "Remove-QuestFile",
            "Show-Menu",
            "Show-Diagnostic",
            "Show-Credit"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }
}

Describe "SkipVideosMod Functions" {
    BeforeAll {
        function Write-Host {}
        Mock Write-Host {}
        Mock Test-Path { return $false }
        Mock Get-ItemProperty {}
    }

    It "Should return null when Arc Raiders is not found" {
        Mock Test-Path { return $false }
        Mock Get-ItemProperty {}
        $result = Find-ArcRaider
        $result | Should -Be $null
    }

    It "Should not throw when removing a non-existent video file" {
        Mock Test-Path { return $false }
        { Remove-VideoFile -Dir "C:\nonexistent" -FileName "test.bk2" } | Should -Not -Throw
    }
}

# File deletion is exercised against throw-away files in $TestDrive only; install-path detection runs on a
# mocked registry and a mocked Test-Path, so a real Arc Raiders install on the machine is never touched.
Describe "SkipVideosMod Remove-VideoFile" {
    BeforeAll {
        Mock Write-Host { }
    }

    BeforeEach {
        $dir = Join-Path $TestDrive 'Movies'
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        $null = New-Item -ItemType Directory -Path $dir
    }

    It "Returns false when the directory does not exist" {
        Remove-VideoFile -Dir (Join-Path $TestDrive 'nope') -FileName 'intro.bk2' | Should -BeFalse
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Directory not found*' }
    }

    It "Returns true and reports 'Already applied' when the file is already gone" {
        Remove-VideoFile -Dir $dir -FileName 'intro.bk2' -Label 'Intro' | Should -BeTrue
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Intro - Already applied*' }
    }

    It "Deletes only the named file" {
        Set-Content -LiteralPath (Join-Path $dir 'intro.bk2') -Value 'x'
        Set-Content -LiteralPath (Join-Path $dir 'other.bk2') -Value 'y'

        Remove-VideoFile -Dir $dir -FileName 'intro.bk2' | Should -BeTrue

        Test-Path (Join-Path $dir 'intro.bk2') | Should -BeFalse
        Test-Path (Join-Path $dir 'other.bk2') | Should -BeTrue
    }

    It "Returns false and keeps the file when deletion fails" {
        Set-Content -LiteralPath (Join-Path $dir 'intro.bk2') -Value 'x'
        Mock Remove-Item { throw 'file is locked' }

        Remove-VideoFile -Dir $dir -FileName 'intro.bk2' | Should -BeFalse

        Test-Path (Join-Path $dir 'intro.bk2') | Should -BeTrue
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Failed to delete file*' }
    }
}

Describe "SkipVideosMod Remove-QuestFile" {
    BeforeAll {
        Mock Write-Host { }
    }

    BeforeEach {
        $MoviesPath = Join-Path $TestDrive 'QuestMovies'
        Remove-Item -LiteralPath $MoviesPath -Recurse -Force -ErrorAction SilentlyContinue
        $questDir = Join-Path $MoviesPath 'Quests'
    }

    It "Reports a missing Quests directory without throwing" {
        { Remove-QuestFile } | Should -Not -Throw
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Directory not found*' }
    }

    It "Reports 'Already applied' when none of the known quest videos exist" {
        $null = New-Item -ItemType Directory -Path $questDir
        Set-Content -LiteralPath (Join-Path $questDir 'unrelated.bk2') -Value 'x'

        Remove-QuestFile

        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Already applied*' }
        Test-Path (Join-Path $questDir 'unrelated.bk2') | Should -BeTrue
    }

    It "Deletes the known quest videos and leaves unrelated files alone" {
        $null = New-Item -ItemType Directory -Path $questDir
        Set-Content -LiteralPath (Join-Path $questDir 'Quest_Intro_A_Bad_Feeling.bk2') -Value 'x'
        Set-Content -LiteralPath (Join-Path $questDir 'QUEST_OUTRO_Into_the_Fray.bk2') -Value 'x'
        Set-Content -LiteralPath (Join-Path $questDir 'keep-me.bk2') -Value 'x'

        Remove-QuestFile

        Test-Path (Join-Path $questDir 'Quest_Intro_A_Bad_Feeling.bk2') | Should -BeFalse
        Test-Path (Join-Path $questDir 'QUEST_OUTRO_Into_the_Fray.bk2') | Should -BeFalse
        Test-Path (Join-Path $questDir 'keep-me.bk2') | Should -BeTrue
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Found 2 of 11 files*' }
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Successfully applied*' }
    }

    It "Reports failure when a video cannot be deleted" {
        $null = New-Item -ItemType Directory -Path $questDir
        Set-Content -LiteralPath (Join-Path $questDir 'QUEST_INTRO_Dormant_Barons.bk2') -Value 'x'
        Mock Remove-Item { throw 'file is locked' }

        Remove-QuestFile

        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Failed to delete files*' }
    }
}

Describe "SkipVideosMod Find-ArcRaider" {
    BeforeEach {
        # Mock bodies resolve this through dynamic scoping
        $arcFind = @{ Existing = @(); Hkcu = $null; Hklm = $null }
        Mock Get-ItemProperty {
            if ($Path -like 'HKCU:*' -and $arcFind.Hkcu) { return [pscustomobject]@{ SteamPath = $arcFind.Hkcu } }
            if ($Path -like 'HKLM:*' -and $arcFind.Hklm) { return [pscustomobject]@{ InstallPath = $arcFind.Hklm } }
            throw 'registry value not found'
        }
        Mock Test-Path { $arcFind.Existing -contains $Path }
    }

    It "Uses the Steam library from the HKCU registry value (forward slashes normalised)" {
        $arcFind.Hkcu = "$env:SystemDrive/FakeGames/Steam"
        $arcFind.Existing = @("$env:SystemDrive\FakeGames\Steam\steamapps\common\Arc Raiders\PioneerGame")

        Find-ArcRaider | Should -Be "$env:SystemDrive\FakeGames\Steam\steamapps\common\Arc Raiders"
    }

    It "Falls back to the HKLM Steam install path" {
        $arcFind.Hklm = "$env:SystemDrive\FakeSteam"
        $arcFind.Existing = @("$env:SystemDrive\FakeSteam\steamapps\common\Arc Raiders\PioneerGame")

        Find-ArcRaider | Should -Be "$env:SystemDrive\FakeSteam\steamapps\common\Arc Raiders"
    }

    It "Falls back to the default Steam folder under Program Files (x86)" {
        $default = Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\Arc Raiders\PioneerGame'
        $arcFind.Existing = @($default)

        Find-ArcRaider | Should -Be (Split-Path $default -Parent)
    }

    It "Falls back to the default Epic Games folder" {
        $epic = Join-Path $env:ProgramFiles 'Epic Games\Arc Raiders\PioneerGame'
        $arcFind.Existing = @($epic)

        Find-ArcRaider | Should -Be (Split-Path $epic -Parent)
    }

    It "Falls back to the script folder when it contains PioneerGame" {
        $scriptDir = (Resolve-Path (Join-Path $PSScriptRoot '..\Scripts\arc-raiders')).Path
        $arcFind.Existing = @((Join-Path $scriptDir 'PioneerGame'))

        Find-ArcRaider | Should -Be $scriptDir
    }

    It "Returns null when no install can be found" {
        Find-ArcRaider | Should -BeNullOrEmpty
    }
}
