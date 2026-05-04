#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/Common.ps1"
}

Describe "ConvertFrom-VDF" {
    It "Should parse basic key-value pairs" {
        $vdf = @"
"AppState"
{
    "appid" "730"

    "name" "Counter-Strike 2"
}
"@
        $lines = $vdf -split "`n"
        $result = ConvertFrom-VDF -Content $lines

        $result.AppState.appid | Should -Be '"730"'
        $result.AppState.name | Should -Be '"Counter-Strike 2"'
    }

    It "Should handle nested objects" {
        $vdf = @"
"AppState"
{
    "InstalledDepots"
    {
        "731"
        {
            "manifest" "12345"
            "size" "67890"
        }
    }
}
"@
        $lines = $vdf -split "`n"
        $result = ConvertFrom-VDF -Content $lines

        $result.AppState.InstalledDepots["731"].manifest | Should -Be '"12345"'
        $result.AppState.InstalledDepots["731"].size | Should -Be '"67890"'
    }

    It "Should handle empty file content" {
        $lines = @()
        $result = ConvertFrom-VDF -Content $lines
        $result.Count | Should -Be 0
    }
}

Describe "ConvertTo-VDF" {
    It "Should convert simple hashtable to VDF" {
        $data = [ordered]@{
            "AppState" = [ordered]@{
                "appid" = "`"730`""
                "name"  = "`"Counter-Strike 2`""
            }
        }

        $result = ConvertTo-VDF -Data $data
        $resultStr = $result -join ''

        # Convert to cross-platform safe string for comparison
        $normalizedResult = $resultStr -replace "`r`n", "`n"

        $expected = "`"AppState`"`n{`n`t`"appid`"`t`t`"730`"`n`t`"name`"`t`t`"Counter-Strike 2`"`n}`n"

        $normalizedResult | Should -Be $expected
    }

    It "Should not output anything if Data is not a dictionary" {
        $result = ConvertTo-VDF -Data "not a dictionary"
        $result | Should -BeNullOrEmpty
    }

    It "Should handle deeper nesting levels" {
        $data = [ordered]@{
            "Level1" = [ordered]@{
                "Level2" = [ordered]@{
                    "key" = "`"value`""
                }
            }
        }

        $result = ConvertTo-VDF -Data $data
        $resultStr = $result -join ''
        $normalizedResult = $resultStr -replace "`r`n", "`n"

        $expected = "`"Level1`"`n{`n`t`"Level2`"`n`t{`n`t`t`"key`"`t`t`"value`"`n`t}`n}`n"
        $normalizedResult | Should -Be $expected
    }
}
Describe "VDF Parsing and Converting" {

    It "Should convert back and forth correctly" {

        $vdf = @"
"AppState"
{
  "appid"    "730"
  "name"    "Counter-Strike 2"
  "SharedDepots"
  {
    "228989"    "228980"
  }
}
"@
        $lines = $vdf -split "`n"
        $parsed = ConvertFrom-VDF -Content $lines

        $converted = ConvertTo-VDF -Data $parsed
        $convertedStr = $converted -join ''
        $normalizedConverted = $convertedStr -replace "`r`n", "`n"

        $expected = "`"AppState`"`n{`n`t`"appid`"`t`t`"730`"`n`t`"name`"`t`t`"Counter-Strike 2`"`n`t`"SharedDepots`"`n`t{`n`t`t`"228989`"`t`t`"228980`"`n`t}`n}`n"

        $normalizedConverted | Should -Be $expected
    }
}

Describe "ConvertFrom-VDF edge cases" {

    It "Should ignore empty lines" {
        $vdf = @"

        "AppState"
        {

            "appid" "730"


        }
"@
        $lines = $vdf -split "`n"
        $result = ConvertFrom-VDF -Content $lines
        $result.AppState.appid | Should -Be '"730"'
    }

    It "Should handle unexpected types" {
        $result = ConvertTo-VDF -Data @("array", "instead", "of", "hash")
        $result | Should -BeNullOrEmpty
    }

    It "Should return empty OrderedDictionary for empty content" {
        $result = ConvertFrom-VDF -Content @()
        $result -is [System.Collections.Specialized.OrderedDictionary] | Should -Be $true
        $result.Count | Should -Be 0
    }
}
Describe "ConvertFrom-VDF values with spaces" {
    It "Should parse values containing spaces correctly" {
        $vdf = @"
        "AppState"
        {
            "name" "Counter-Strike Global Offensive"

            "path" "C:\Program Files (x86)\Steam"

        }
"@
        $lines = $vdf -split "`n"
        $result = ConvertFrom-VDF -Content $lines
        $result.AppState.name | Should -Be '"Counter-Strike Global Offensive"'
        $result.AppState.path | Should -Be '"C:\Program Files (x86)\Steam"'
    }
}

Describe "Show-RestartRequired" {
    It "Should call Write-Host and Wait-ForKeyPress" {
        Mock Write-Host
        Mock Wait-ForKeyPress

        Show-RestartRequired

        Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter { $Object -eq "Restart required to apply changes..." -and $ForegroundColor -eq "Yellow" }
        Should -Invoke -CommandName Wait-ForKeyPress -Times 1
    }

    It "Should call Write-Host with custom message" {
        Mock Write-Host
        Mock Wait-ForKeyPress

        $msg = "Custom Restart Message"
        Show-RestartRequired -CustomMessage $msg

        Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter { $Object -eq $msg -and $ForegroundColor -eq "Yellow" }
        Should -Invoke -CommandName Wait-ForKeyPress -Times 1
    }
}

Describe "Invoke-ServiceOperation" {
    BeforeAll {
        function Get-Service { param($Name, $ErrorAction) }
        function Stop-Service { param($Name, $Force, $ErrorAction) }
        function Start-Service { param($Name, $ErrorAction) }
        function Write-Warn { param($Message) }
    }

    It "Should do nothing and warn if service is not found" {
        Mock -CommandName Get-Service { return $null }
        Mock -CommandName Write-Warn {}

        $global:actionExecuted = $false
        $action = { $global:actionExecuted = $true }

        Invoke-ServiceOperation -Name "NonExistentService" -Action $action

        Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "NonExistentService" }
        Should -Invoke -CommandName Write-Warn -Times 1 -ParameterFilter { $Message -eq "Service 'NonExistentService' not found" }
        $global:actionExecuted | Should -Be $false
    }

    It "Should not stop or start if the service is not running" {
        Mock -CommandName Get-Service { return [pscustomobject]@{ Status = 'Stopped' } }
        Mock -CommandName Stop-Service {}
        Mock -CommandName Start-Service {}

        $global:actionExecuted = $false
        $action = { $global:actionExecuted = $true }

        Invoke-ServiceOperation -Name "StoppedService" -Action $action

        Should -Invoke -CommandName Stop-Service -Times 0
        Should -Invoke -CommandName Start-Service -Times 0
        $global:actionExecuted | Should -Be $true
    }

    It "Should stop, execute action, and start if service is running" {
        Mock -CommandName Get-Service { return [pscustomobject]@{ Status = 'Running' } }
        Mock -CommandName Stop-Service {}
        Mock -CommandName Start-Service {}

        $global:actionExecuted = $false
        $action = {
            $global:actionExecuted = $true
            Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "RunningService" }
        }

        Invoke-ServiceOperation -Name "RunningService" -Action $action

        Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "RunningService" }
        Should -Invoke -CommandName Start-Service -Times 1 -ParameterFilter { $Name -eq "RunningService" }
        $global:actionExecuted | Should -Be $true
    }

    It "Should stop and execute, but not start if Restart is `$false" {
        Mock -CommandName Get-Service { return [pscustomobject]@{ Status = 'Running' } }
        Mock -CommandName Stop-Service {}
        Mock -CommandName Start-Service {}

        $global:actionExecuted = $false
        $action = { $global:actionExecuted = $true }

        Invoke-ServiceOperation -Name "RunningService" -Action $action -Restart $false

        Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "RunningService" }
        Should -Invoke -CommandName Start-Service -Times 0
        $global:actionExecuted | Should -Be $true
    }

    It "Should still restart service if action throws an error" {
        Mock -CommandName Get-Service { return [pscustomobject]@{ Status = 'Running' } }
        Mock -CommandName Stop-Service {}
        Mock -CommandName Start-Service {}

        $action = { throw "Simulated action failure" }

        { Invoke-ServiceOperation -Name "RunningService" -Action $action } | Should -Throw "Simulated action failure"

        Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq "RunningService" }
        Should -Invoke -CommandName Start-Service -Times 1 -ParameterFilter { $Name -eq "RunningService" }
    }
}
