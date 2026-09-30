#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dispatcher is guarded by the InvocationName check; dot-sourcing only defines functions.
    . "$PSScriptRoot/../Scripts/Setup-ClaudeCode.ps1"

    # Stub so the real claude CLI is never resolved; every test mocks it.
    function claude { }
}

Describe 'Setup-ClaudeCode.ps1' {
    BeforeEach {
        $failures.Clear()
        Mock Write-Host { }
        Mock Write-Success { }
        Mock Write-Warn { }
        # Default: nothing known/registered yet, every add succeeds.
        Mock claude {
            $global:LASTEXITCODE = if ($args[0] -eq 'mcp' -and $args[1] -eq 'get') { 1 } else { 0 }
        }
    }

    Context 'Install-ClaudeMarketplace' {
        It 'Skips a marketplace that is already known' {
            Mock claude { 'caveman   github   owner/caveman' } -ParameterFilter { $args -contains 'list' }

            Install-ClaudeMarketplace -Name 'caveman' -Repo 'owner/caveman'

            Should -Invoke claude -Times 0 -Exactly -ParameterFilter { $args -contains 'add' }
        }

        It 'Adds an unknown marketplace by its owner/repo slug' {
            Install-ClaudeMarketplace -Name 'caveman' -Repo 'owner/caveman'

            Should -Invoke claude -Times 1 -Exactly -ParameterFilter {
                ($args -join ' ') -eq 'plugin marketplace add owner/caveman'
            }
        }

        It 'Throws with the exit code when the add fails' {
            Mock claude { $global:LASTEXITCODE = 3 } -ParameterFilter { $args -contains 'add' }

            { Install-ClaudeMarketplace -Name 'x' -Repo 'owner/x' } |
                Should -Throw -ExpectedMessage '*exited 3*'
        }

        It 'Honors -WhatIf' {
            Install-ClaudeMarketplace -Name 'caveman' -Repo 'owner/caveman' -WhatIf

            Should -Invoke claude -Times 0 -Exactly -ParameterFilter { $args -contains 'add' }
        }
    }

    Context 'Install-ClaudePlugin' {
        It 'Matches installed plugin ids literally, not as a regex' {
            # "a.b@m" as a regex would match "aXb@m" and wrongly skip the install.
            Mock claude { 'aXb@m' } -ParameterFilter { $args -contains 'list' }

            Install-ClaudePlugin -PluginId 'a.b@m'

            Should -Invoke claude -Times 1 -Exactly -ParameterFilter {
                ($args -join ' ') -eq 'plugin install a.b@m'
            }
        }
    }

    Context 'Install-ClaudeMcpServer' {
        It 'Skips a server that "claude mcp get" already knows' {
            Mock claude { $global:LASTEXITCODE = 0 }

            Install-ClaudeMcpServer -Name 'serena' -Definition ([pscustomobject]@{ type = 'stdio' })

            Should -Invoke claude -Times 0 -Exactly -ParameterFilter { $args -contains 'add-json' }
        }

        It 'Registers at user scope with the definition as compressed JSON' {
            $definition = [pscustomobject]@{ type = 'stdio'; command = 'bunx'; args = @('--bun', 'x') }

            Install-ClaudeMcpServer -Name 'x' -Definition $definition

            Should -Invoke claude -Times 1 -Exactly -ParameterFilter {
                $args[1] -eq 'add-json' -and $args[2] -eq 'x' -and
                $args[3] -eq '{"type":"stdio","command":"bunx","args":["--bun","x"]}' -and
                ($args[4..5] -join ' ') -eq '--scope user'
            }
        }
    }

    Context 'Start-ClaudeCodeSetup' {
        BeforeEach {
            $settingsPath = Join-Path $TestDrive 'settings.json'
            $mcpServersPath = Join-Path $TestDrive 'mcp-servers.json'
            Set-Content -LiteralPath $settingsPath -Value (@{
                    extraKnownMarketplaces = @{
                        good = @{ source = @{ repo = 'owner/good' } }
                        bad  = @{ source = @{ repo = 'owner/bad' } }
                    }
                    enabledPlugins         = @{ 'on@good' = $true; 'off@good' = $false }
                } | ConvertTo-Json -Depth 5)
            Set-Content -LiteralPath $mcpServersPath -Value (@{
                    octocode = @{ type = 'stdio'; command = 'bunx'; env = @{ LOG = 'false' } }
                } | ConvertTo-Json -Depth 5)
        }

        It 'Fails fast when the claude CLI is not on PATH' {
            Mock Test-ClaudeCliAvailable { $false }

            { Start-ClaudeCodeSetup } | Should -Throw -ExpectedMessage "*'claude' CLI not found*"
        }

        It 'Collects a failing step and still runs the rest' {
            Mock claude { $global:LASTEXITCODE = 1 } -ParameterFilter { $args -contains 'owner/bad' }
            $GitHubToken = $null

            $result = Start-ClaudeCodeSetup

            $result.FailureCount | Should -Be 1
            $failures[0].Label | Should -Be 'Marketplace bad'
            Should -Invoke claude -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'plugin install on@good' }
            Should -Invoke claude -Times 1 -Exactly -ParameterFilter { $args -contains 'add-json' }
        }

        It 'Skips disabled plugins' {
            $null = Start-ClaudeCodeSetup

            Should -Invoke claude -Times 0 -Exactly -ParameterFilter { $args -contains 'off@good' }
        }

        It 'Injects GITHUB_TOKEN into the octocode env when a token is given' {
            $GitHubToken = 'test-token-value'

            $null = Start-ClaudeCodeSetup

            Should -Invoke claude -Times 1 -Exactly -ParameterFilter {
                $args[2] -eq 'octocode' -and
                $args[3] -like '*"GITHUB_TOKEN":"test-token-value"*' -and $args[3] -like '*"LOG":"false"*'
            }
        }

        It 'Warns and omits GITHUB_TOKEN when no token is available' {
            $GitHubToken = $null

            $null = Start-ClaudeCodeSetup

            Should -Invoke Write-Warn -Times 1 -Exactly
            Should -Invoke claude -Times 0 -Exactly -ParameterFilter { $args -like '*GITHUB_TOKEN*' }
        }
    }
}
