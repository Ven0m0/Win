#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "game-boost.ps1 (thin wrapper)" {
    It "Should safely source the script" {
        { . "$PSScriptRoot/../Scripts/arc-raiders/game-boost.ps1" } | Should -Not -Throw
    }

    It "Should delegate to start-optimized-game.ps1 with the Arc Raiders manifest" {
        $content = Get-Content -Raw "$PSScriptRoot/../Scripts/arc-raiders/game-boost.ps1"
        $content | Should -Match 'start-optimized-game\.ps1'
        $content | Should -Match 'arc-raiders\.psd1'
    }
}
