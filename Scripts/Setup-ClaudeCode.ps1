#Requires -Version 5.1

<#
.SYNOPSIS
    Installs the Claude Code marketplaces, plugins, and MCP servers tracked in this repo.
.DESCRIPTION
    Reads user/.dotfiles/config/claude/settings.json (marketplaces + plugins) and
    user/.dotfiles/config/claude/mcp-servers.json (MCP servers) as the manifest, and
    reproduces that setup via the `claude` CLI. Idempotent: every step is skipped if
    already installed. Never aborts on a single failure; failures are collected and
    printed under "STEPS THAT FAILED" at the end, matching Setup-Dotfiles.ps1.
.PARAMETER GitHubToken
    Token to inject into the octocode MCP server's environment as GITHUB_TOKEN.
    Defaults to $env:GITHUB_TOKEN. If neither is set, octocode installs without a
    token (works unauthenticated at lower rate limits).
.EXAMPLE
    .\Setup-ClaudeCode.ps1
.EXAMPLE
    .\Setup-ClaudeCode.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

. "$PSScriptRoot\Common.ps1"

$ErrorActionPreference = 'Stop'

$configRoot = Join-Path $PSScriptRoot '..\user\.dotfiles\config\claude'
$settingsPath = Join-Path $configRoot 'settings.json'
$mcpServersPath = Join-Path $configRoot 'mcp-servers.json'
$failures = [System.Collections.Generic.List[pscustomobject]]::new()

function Test-ClaudeCliAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $null -ne (Get-Command claude -ErrorAction SilentlyContinue)
}

function Install-ClaudeMarketplace {
    <#
    .SYNOPSIS
        Adds a Claude Code plugin marketplace if it is not already known.
    .PARAMETER Name
        Marketplace name (key in extraKnownMarketplaces).
    .PARAMETER Repo
        owner/repo slug from the marketplace's source.repo field.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Repo
    )

    $known = & claude plugin marketplace list 2>$null
    if ($known -match [regex]::Escape($Name)) {
        Write-Host "  [SKIP] Marketplace $Name - already known" -ForegroundColor Gray
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Add Claude Code marketplace')) {
        & claude plugin marketplace add $Repo 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Marketplace $Name added"
        }
        else {
            throw "claude plugin marketplace add $Repo exited $LASTEXITCODE"
        }
    }
}

function Install-ClaudePlugin {
    <#
    .SYNOPSIS
        Installs a Claude Code plugin if it is not already installed.
    .PARAMETER PluginId
        Plugin id in `plugin@marketplace` form.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$PluginId
    )

    $known = & claude plugin list 2>$null
    if ($known -match [regex]::Escape($PluginId)) {
        Write-Host "  [SKIP] Plugin $PluginId - already installed" -ForegroundColor Gray
        return
    }

    if ($PSCmdlet.ShouldProcess($PluginId, 'Install Claude Code plugin')) {
        & claude plugin install $PluginId 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Plugin $PluginId installed"
        }
        else {
            throw "claude plugin install $PluginId exited $LASTEXITCODE"
        }
    }
}

function Install-ClaudeMcpServer {
    <#
    .SYNOPSIS
        Registers an MCP server with the Claude Code CLI if it is not already registered.
    .PARAMETER Name
        MCP server name.
    .PARAMETER Definition
        Server definition object (type/command/args/env) from mcp-servers.json.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [pscustomobject]$Definition
    )

    & claude mcp get $Name *>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [SKIP] MCP server $Name - already registered" -ForegroundColor Gray
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Register MCP server')) {
        $json = $Definition | ConvertTo-Json -Depth 6 -Compress
        & claude mcp add-json $Name $json --scope user 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "MCP server $Name registered"
        }
        else {
            throw "claude mcp add-json $Name exited $LASTEXITCODE"
        }
    }
}

function Start-ClaudeCodeSetup {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Test-ClaudeCliAvailable)) {
        throw "'claude' CLI not found on PATH. Install Claude Code first."
    }

    Write-Host ''
    Write-Host 'Claude Code marketplaces' -ForegroundColor Cyan
    $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    foreach ($name in $settings.extraKnownMarketplaces.PSObject.Properties.Name) {
        $repo = $settings.extraKnownMarketplaces.$name.source.repo
        try {
            Install-ClaudeMarketplace -Name $name -Repo $repo
        }
        catch {
            $failures.Add([pscustomobject]@{ Label = "Marketplace $name"; Error = $_.Exception.Message })
        }
    }

    Write-Host ''
    Write-Host 'Claude Code plugins' -ForegroundColor Cyan
    foreach ($pluginId in $settings.enabledPlugins.PSObject.Properties.Name) {
        if (-not $settings.enabledPlugins.$pluginId) { continue }
        try {
            Install-ClaudePlugin -PluginId $pluginId
        }
        catch {
            $failures.Add([pscustomobject]@{ Label = "Plugin $pluginId"; Error = $_.Exception.Message })
        }
    }

    Write-Host ''
    Write-Host 'Claude Code MCP servers' -ForegroundColor Cyan
    if (-not $GitHubToken) {
        Write-Warn 'GITHUB_TOKEN not set - octocode will install without one (lower rate limits)'
    }
    $mcpServers = Get-Content -Path $mcpServersPath -Raw | ConvertFrom-Json
    foreach ($name in $mcpServers.PSObject.Properties.Name) {
        $definition = $mcpServers.$name
        if ($name -eq 'octocode' -and $GitHubToken) {
            $definition.env | Add-Member -MemberType NoteProperty -Name 'GITHUB_TOKEN' -Value $GitHubToken -Force
        }
        try {
            Install-ClaudeMcpServer -Name $name -Definition $definition
        }
        catch {
            $failures.Add([pscustomobject]@{ Label = "MCP server $name"; Error = $_.Exception.Message })
        }
    }

    Write-Host ''
    if ($failures.Count -gt 0) {
        Write-Host 'STEPS THAT FAILED (fix manually):' -ForegroundColor Red
        foreach ($f in $failures) {
            Write-Host "  [FAIL] $($f.Label): $($f.Error)" -ForegroundColor Red
        }
    }
    else {
        Write-Host '  All Claude Code setup steps succeeded.' -ForegroundColor Green
    }
    Write-Host ''

    return [pscustomobject]@{ FailureCount = $failures.Count }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-ClaudeCodeSetup
    exit ([int]($result.FailureCount -gt 0))
}
