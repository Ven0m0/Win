#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/sanitize-filenames.ps1"
}

Describe 'sanitize-filenames.ps1' {
    BeforeEach {
        $script:TestRoot = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    }

    Context 'Preview mode (default)' {
        It 'Does not rename anything without -Apply' {
            $file = Join-Path $TestRoot 'My File (1).txt'
            Set-Content -LiteralPath $file -Value 'x'

            & $ScriptPath -Path $TestRoot *> $null

            Test-Path -LiteralPath $file | Should -BeTrue
        }
    }

    Context 'Apply mode' {
        It 'Replaces spaces and special characters, and lowercases the result' {
            $file = Join-Path $TestRoot 'My File (1).txt'
            Set-Content -LiteralPath $file -Value 'x'

            & $ScriptPath -Path $TestRoot -Apply *> $null

            # ConvertTo-SafeFileName only trims _/./- from the very start/end of the whole
            # string, so "(1)" collapses to "_1_" and the trailing underscore before the
            # extension survives - this is the shared helper's existing behavior, not new.
            Test-Path -LiteralPath (Join-Path $TestRoot 'my_file_1_.txt') | Should -BeTrue
            Test-Path -LiteralPath $file | Should -BeFalse
        }

        It 'Renames nested directories depth-first without orphaning child files' {
            $innerDir = Join-Path $TestRoot 'Some Folder'
            New-Item -ItemType Directory -Path $innerDir -Force | Out-Null
            $innerFile = Join-Path $innerDir 'Inner File.mp3'
            Set-Content -LiteralPath $innerFile -Value 'x'

            & $ScriptPath -Path $TestRoot -Apply *> $null

            Test-Path -LiteralPath (Join-Path $TestRoot 'some_folder/inner_file.mp3') | Should -BeTrue
        }

        It 'Resolves collisions by appending a numeric suffix without overwriting either file' {
            # NTFS is case-insensitive, so names that are case-variants of each other (or of the
            # sanitized target) can't coexist as distinct files - use two names that differ by a
            # non-case character (space vs '!') but sanitize to the identical result.
            $fileA = Join-Path $TestRoot 'My File.txt'
            $fileB = Join-Path $TestRoot 'My!File.txt'
            Set-Content -LiteralPath $fileA -Value 'A'
            Set-Content -LiteralPath $fileB -Value 'B'

            & $ScriptPath -Path $TestRoot -Apply *> $null

            $survivors = Get-ChildItem -LiteralPath $TestRoot -File
            $survivors.Count | Should -Be 2
            $survivors.Name | Should -Contain 'my_file.txt'
            $survivors.Name | Should -Contain 'my_file_1.txt'
        }
    }
}
