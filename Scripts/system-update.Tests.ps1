BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "system-update.ps1" {
    Context "Syntax and Basic Execution" {
        It "Can be parsed and executed without throwing" {
            $content = Get-Content "$PSScriptRoot/system-update.ps1" -Raw
            $adminCheck = "([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]"
            $adminCheck += "::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]""Administrator"")"
            $content = $content.Replace($adminCheck, '$true')
            $content = $content.Replace('$env:LOCALAPPDATA', "'$PSScriptRoot'")
            $content = $content.Replace('$env:SystemRoot', "'$PSScriptRoot'")
            $content = $content.Replace('$env:ProgramFiles', "'$PSScriptRoot'")
            $content = $content.Replace('${env:ProgramFiles(x86)}', "'$PSScriptRoot'")
            $content = $content.Replace('$env:TEMP', "'$PSScriptRoot'")
            $content = $content.Replace('$env:APPDATA', "'$PSScriptRoot'")

            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                # We need to skip commands that aren't on Linux
                . $tempScript -DryRun -WhatChanged -SkipCleanup -SkipWindowsUpdate
            }

            $runBlock | Should -Not -Throw

            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }

        It "Completes with all skip flags enabled" {
            $content = Get-Content "$PSScriptRoot/system-update.ps1" -Raw
            $adminCheck = "([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]"
            $adminCheck += "::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]""Administrator"")"
            $content = $content.Replace($adminCheck, '$true')
            $content = $content.Replace('$env:LOCALAPPDATA', "'$PSScriptRoot'")
            $content = $content.Replace('$env:SystemRoot', "'$PSScriptRoot'")
            $content = $content.Replace('$env:ProgramFiles', "'$PSScriptRoot'")
            $content = $content.Replace('${env:ProgramFiles(x86)}', "'$PSScriptRoot'")
            $content = $content.Replace('$env:TEMP', "'$PSScriptRoot'")
            $content = $content.Replace('$env:APPDATA', "'$PSScriptRoot'")

            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                . $tempScript -DryRun -SkipCleanup -SkipWindowsUpdate `
                -SkipNode -SkipRust -SkipGo -SkipFlutter -SkipGitLFS `
                -SkipWSL -SkipVSCodeExtensions -SkipPowerShellModules
            }

            $runBlock | Should -Not -Throw

            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }
    }
}
