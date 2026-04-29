BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Create a dummy function with CmdletBinding to export PSCmdlet
    function Get-DummyPSCmdlet {
        [CmdletBinding(SupportsShouldProcess)]
        param()
        return $PSCmdlet
    }
    $global:PSCmdlet = Get-DummyPSCmdlet

    $global:script:ConfigRoot = "dummy"
    $global:script:Results = @{}

    . "$PSScriptRoot/Deploy-Config.ps1"

    $script:Results = @{}
}

Describe "Write-Status" {
    It "Should add to script:Results with default INFO status" {
        $script:Results.Clear()
        Write-Status -Message "Test Message"

        $script:Results["Test Message"] | Should -Be "INFO"
    }

    It "Should add to script:Results with provided status" {
        $script:Results.Clear()
        Write-Status -Message "Test OK" -Status "OK"

        $script:Results["Test OK"] | Should -Be "OK"
    }
}

Describe "Deploy-ConfigFile" {
    BeforeEach {
        $script:Results.Clear()
        $testDir = New-TemporaryFile | Select-Object -ExpandProperty DirectoryName
        $testSrc = Join-Path $testDir "src.txt"
        $testDest = Join-Path $testDir "dest.txt"
    }

    AfterEach {
        if (Test-Path $testSrc) { Remove-Item $testSrc -Force }
        if (Test-Path $testDest) { Remove-Item $testDest -Force }
    }

    It "Should skip if source does not exist" {
        $result = Deploy-ConfigFile -Source "nonexistent.txt" -Destination "dest.txt" -Label "Test Skip"
        $result | Should -Be $false
        $script:Results["Test Skip - source not found: nonexistent.txt"] | Should -Be "SKIP"
    }

    It "Should copy if destination does not exist" {
        Set-Content -Path $testSrc -Value "Test Data"

        $result = Deploy-ConfigFile -Source $testSrc -Destination $testDest -Label "Test Copy"
        $result | Should -Be $true
        Test-Path $testDest | Should -Be $true
        $script:Results["Test Copy deployed"] | Should -Be "OK"
    }

    It "Should skip if destination exists and hashes match" {
        Set-Content -Path $testSrc -Value "Same Data"
        Set-Content -Path $testDest -Value "Same Data"

        $result = Deploy-ConfigFile -Source $testSrc -Destination $testDest -Label "Test Match"
        $result | Should -Be $false
        $script:Results["Test Match - up to date"] | Should -Be "UP-TO-DATE"
    }

    It "Should overwrite if hashes differ" {
        Set-Content -Path $testSrc -Value "New Data"
        Set-Content -Path $testDest -Value "Old Data"

        $result = Deploy-ConfigFile -Source $testSrc -Destination $testDest -Label "Test Overwrite"
        $result | Should -Be $true
        Get-Content $testDest | Should -Be "New Data"
        $script:Results["Test Overwrite deployed"] | Should -Be "OK"
    }
}

Describe "Deploy-ConfigDirectory" {
    BeforeEach {
        $script:Results.Clear()
        $testDir = New-TemporaryFile | Select-Object -ExpandProperty DirectoryName
        $testSrcDir = Join-Path $testDir "srcDir"
        $testDestDir = Join-Path $testDir "destDir"
        New-Item -ItemType Directory -Path $testSrcDir | Out-Null
        New-Item -ItemType Directory -Path $testDestDir | Out-Null

        Set-Content -Path (Join-Path $testSrcDir "file1.txt") -Value "Data1"
        Set-Content -Path (Join-Path $testSrcDir "file2.txt") -Value "Data2"
    }

    AfterEach {
        if (Test-Path $testSrcDir) { Remove-Item $testSrcDir -Recurse -Force }
        if (Test-Path $testDestDir) { Remove-Item $testDestDir -Recurse -Force }
    }

    It "Should skip if source directory does not exist" {
        Deploy-ConfigDirectory -SourceDir "nonexistentDir" -DestDir $testDestDir -Label "Test Dir Skip"
        $script:Results["Test Dir Skip - source directory not found: nonexistentDir"] | Should -Be "SKIP"
    }

    It "Should deploy multiple files" {
        Deploy-ConfigDirectory -SourceDir $testSrcDir -DestDir $testDestDir -Label "Test Dir"

        Test-Path (Join-Path $testDestDir "file1.txt") | Should -Be $true
        Test-Path (Join-Path $testDestDir "file2.txt") | Should -Be $true
        $script:Results["Test Dir/file1.txt deployed"] | Should -Be "OK"
        $script:Results["Test Dir/file2.txt deployed"] | Should -Be "OK"
    }
}

Describe "Get-CallOfDutyPlayersPath" {
    BeforeAll {
        Set-Item -Path "Function:Get-CallOfDutyPlayersPath" -Value ([scriptblock]::Create("
            `$playersPath = Join-Path '/tmp' 'Call of Duty\\players'
            if (Test-Path `$playersPath) { return `$playersPath }
            return `$null
        "))
    }

    It "Should return path if it exists" {
        Mock Test-Path { return $true }

        $result = Get-CallOfDutyPlayersPath
        $result -match "Call of Duty.*players" | Should -Be $true
    }

    It "Should return null if path does not exist" {
        Mock Test-Path { return $false }

        $result = Get-CallOfDutyPlayersPath
        $result | Should -BeNullOrEmpty
    }
}
