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

        $expected = "`"AppState`"`n{`n`t`"appid`"`t`t`"730`"`n`t`"name`"`t`t`"Counter-Strike 2`"`n`t" +
            "`"SharedDepots`"`n`t{`n`t`t`"228989`"`t`t`"228980`"`n`t}`n}`n"

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
        Mock Write-ColorOutput
        Mock Wait-ForKeyPress

        Show-RestartRequired

        Should -Invoke -CommandName Write-ColorOutput -Times 1 -ParameterFilter {
            $Object -eq "Restart required to apply changes..." -and $ForegroundColor -eq "Yellow"
        }
        Should -Invoke -CommandName Wait-ForKeyPress -Times 1
    }

    It "Should call Write-Host with custom message" {
        Mock Write-ColorOutput
        Mock Wait-ForKeyPress

        $msg = "Custom Restart Message"
        Show-RestartRequired -CustomMessage $msg

        Should -Invoke -CommandName Write-ColorOutput -Times 1 -ParameterFilter {
            $Object -eq $msg -and $ForegroundColor -eq "Yellow"
        }
        Should -Invoke -CommandName Wait-ForKeyPress -Times 1
    }
}


Describe "Get-NvidiaGpuRegistryPath" {
    It "Should call Get-ChildItem with correct registry path" {
        Mock Get-ChildItem {
            return @()
        }

        $null = Get-NvidiaGpuRegistryPath

        Should -Invoke -CommandName Get-ChildItem -Times 1 -ParameterFilter {
            $expected = "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            $Path -match [regex]::Escape($expected)
        }
    }

    It "Should return subkeys excluding those ending in 'Configuration'" {
        Mock Get-ChildItem {
            return @(
                [pscustomobject]@{Name="0000"}
                [pscustomobject]@{Name="0001"}
                [pscustomobject]@{Name="Configuration"}
                [pscustomobject]@{Name="VideoConfiguration"}
            )
        }

        $result = Get-NvidiaGpuRegistryPath

        $result | Should -HaveCount 2
        $result | Should -Contain "0000"
        $result | Should -Contain "0001"
        $result | Should -Not -Contain "Configuration"
        $result | Should -Not -Contain "VideoConfiguration"
    }

    It "Should handle null output from Get-ChildItem" {
        Mock Get-ChildItem {
            return $null
        }

        $result = Get-NvidiaGpuRegistryPath

        $result | Should -BeNullOrEmpty
    }
}

Describe "Get-FolderSize" {
    It "Should return 0 if path does not exist" {
        Mock Test-Path { return $false }

        $result = Get-FolderSize -Path "/tmp/FakePath"

        $result | Should -Be 0
        Should -Invoke -CommandName Test-Path -Times 1 -ParameterFilter { $Path -eq "/tmp/FakePath" }
    }

    It "Should return correct size in B" {
        Mock Test-Path { return $true }
        Mock Get-ChildItem {
            param($Path, [switch]$Recurse, [switch]$File, [switch]$Force, $ErrorAction)
            return @(
                [pscustomobject]@{ Length = 500 },
                [pscustomobject]@{ Length = 524 }
            )
        }

        $result = Get-FolderSize -Path "/tmp/FakePath" -Unit 'B'

        $result | Should -Be 1024
        Should -Invoke -CommandName Get-ChildItem -Times 1 -ParameterFilter { $Path -eq "/tmp/FakePath" }
    }

    It "Should return correct size in KB" {
        Mock Test-Path { return $true }
        Mock Get-ChildItem {
            param($Path, [switch]$Recurse, [switch]$File, [switch]$Force, $ErrorAction)
            return @(
                [pscustomobject]@{ Length = 1024 },
                [pscustomobject]@{ Length = 1024 }
            )
        }

        $result = Get-FolderSize -Path "/tmp/FakePath" -Unit 'KB'

        $result | Should -Be 2
    }

    It "Should return correct size in MB" {
        Mock Test-Path { return $true }
        Mock Get-ChildItem {
            param($Path, [switch]$Recurse, [switch]$File, [switch]$Force, $ErrorAction)
            return @(
                [pscustomobject]@{ Length = 1048576 }
            )
        }

        $result = Get-FolderSize -Path "/tmp/FakePath" -Unit 'MB'

        $result | Should -Be 1
    }

    It "Should return correct size in GB" {
        Mock Test-Path { return $true }
        Mock Get-ChildItem {
            param($Path, [switch]$Recurse, [switch]$File, [switch]$Force, $ErrorAction)
            return @(
                [pscustomobject]@{ Length = 1073741824 }
            )
        }

        $result = Get-FolderSize -Path "/tmp/FakePath" -Unit 'GB'

        $result | Should -Be 1
    }

    It "Should return correct size in MB by default" {
        Mock Test-Path { return $true }
        Mock Get-ChildItem {
            param($Path, [switch]$Recurse, [switch]$File, [switch]$Force, $ErrorAction)
            return @(
                [pscustomobject]@{ Length = 2097152 }
            )
        }

        $result = Get-FolderSize -Path "/tmp/FakePath"

        $result | Should -Be 2
    }
}

Describe "Clear-PathSafe" {
    It "Should use Remove-Item with Recurse for wildcard paths" {
        Mock Remove-Item { }

        Clear-PathSafe -Path "C:\Temp\*"

        Should -Invoke -CommandName Remove-Item -Times 1 -ParameterFilter {
            $Path -eq "C:\Temp\*" -and $Recurse -and $Force
        }
    }

    It "Should do nothing if non-wildcard path does not exist" {
        Mock Test-Path { return $false }
        Mock Remove-Item { }
        Mock Clear-DirectorySafe { }

        Clear-PathSafe -Path "C:\Temp\NonExistent"

        Should -Invoke -CommandName Test-Path -Times 1 -ParameterFilter { $Path -eq "C:\Temp\NonExistent" }
        Should -Invoke -CommandName Remove-Item -Times 0
        Should -Invoke -CommandName Clear-DirectorySafe -Times 0
    }

    It "Should call Clear-DirectorySafe for directories" {
        Mock Test-Path {
            if ($PathType -eq 'Container') { return $true }
            return $true
        }
        Mock Clear-DirectorySafe { }
        Mock Remove-Item { }

        Clear-PathSafe -Path "C:\Temp\MyFolder"

        Should -Invoke -CommandName Test-Path -Times 1 -ParameterFilter {
            $Path -eq "C:\Temp\MyFolder" -and (-not $PathType)
        }
        Should -Invoke -CommandName Test-Path -Times 1 -ParameterFilter {
            $Path -eq "C:\Temp\MyFolder" -and $PathType -eq 'Container'
        }
        Should -Invoke -CommandName Clear-DirectorySafe -Times 1 -ParameterFilter { $Path -eq "C:\Temp\MyFolder" }
        Should -Invoke -CommandName Remove-Item -Times 0
    }

    It "Should use Remove-Item without Recurse for single files" {
        Mock Test-Path {
            if ($PathType -eq 'Container') { return $false }
            return $true
        }
        Mock Remove-Item { }
        Mock Clear-DirectorySafe { }

        Clear-PathSafe -Path "C:\Temp\MyFile.txt"

        Should -Invoke -CommandName Test-Path -Times 1 -ParameterFilter {
            $Path -eq "C:\Temp\MyFile.txt" -and (-not $PathType)
        }
        Should -Invoke -CommandName Test-Path -Times 1 -ParameterFilter {
            $Path -eq "C:\Temp\MyFile.txt" -and $PathType -eq 'Container'
        }
        Should -Invoke -CommandName Remove-Item -Times 1 -ParameterFilter {
            $Path -eq "C:\Temp\MyFile.txt" -and $Force
        }
        Should -Invoke -CommandName Clear-DirectorySafe -Times 0
    }
}
