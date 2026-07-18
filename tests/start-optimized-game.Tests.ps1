#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:Manifest = "$PSScriptRoot/../Scripts/arc-raiders/arc-raiders.psd1"
    . "$PSScriptRoot/../Scripts/start-optimized-game.ps1" -GameManifest $script:Manifest
}

Describe "start-optimized-game.ps1 Initialization" {
    It "Should safely source the script" {
        $true | Should -Be $true
    }

    It "Should export the expected functions" {
        $expectedFunctions = @(
            "Invoke-SelfElevation",
            "Get-PowerPlan",
            "Format-MB",
            "Get-GameProcess",
            "Start-Game",
            "Save-State",
            "Import-State",
            "Clear-State",
            "Restore-All"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }

    It "Should load the Arc Raiders manifest into the expected shape" {
        $GAME_NAMES | Should -Contain 'PioneerGame'
        $DISPLAY_NAME | Should -Be 'ARC RAIDERS'
        $STEAM_GAME_ID | Should -Be '1808500'
    }

    It "Should define the kill list without protected process collisions" {
        foreach ($proc in $PROTECTED) {
            $KILL_LIST.Keys -notcontains $proc | Should -Be $true
        }
    }
}

Describe "start-optimized-game.ps1 Functions Dry Run" {
    BeforeAll {
        function Write-Host {}
        Mock Write-Host {}
        Mock Get-Process {}
        Mock Get-CimInstance { return [pscustomobject]@{ FreePhysicalMemory = 8000000 } }
    }

    It "Should run Format-MB correctly" {
        $result = Format-MB 1048576
        $result | Should -Be "1.0 MB"
    }

    It "Should not throw when no game process is running" {
        Mock Get-Process {}
        $result = Get-GameProcess
        $result | Should -Be $null
    }
}
