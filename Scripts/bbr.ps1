#Requires -Version 5.1
<#
.SYNOPSIS
  Switch the TCP congestion provider between bbr2 and cubic and apply related TCP globals.
.DESCRIPTION
  bbr2 can break Steam downloads; use -Provider cubic to switch back when needed.
  Without -Provider, shows a 1/2 menu.
.EXAMPLE
  .\bbr.ps1 -Provider cubic
  Reverts to cubic (Steam-safe).
#>
[CmdletBinding(SupportsShouldProcess)]
param (
  # Congestion provider for the internet template
  [ValidateSet('bbr2', 'cubic')]
  [string]$Provider
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

# Menu runs before elevation so the choice is forwarded to the elevated relaunch.
if (-not $Provider) {
  Write-Information -MessageData "TCP congestion provider`n  1) bbr2`n  2) cubic (Steam-safe)" -InformationAction Continue
  $choice = Read-Host -Prompt 'Select [1/2]'
  $Provider = switch ($choice) {
    '1' { 'bbr2' }
    '2' { 'cubic' }
    default { throw "Invalid choice: '$choice'" }
  }
  $PSBoundParameters['Provider'] = $Provider
}

Request-AdminElevation -BoundParameters $PSBoundParameters

$settings = @(
  "supplemental template=internet congestionprovider=$Provider"
  'global rss=enabled'
  'global fastopen=enabled'
  'global ecncapability=enabled'
)

foreach ($setting in $settings) {
  if ($PSCmdlet.ShouldProcess($setting, 'netsh int tcp set')) {
    & netsh.exe int tcp set @($setting -split ' ')
    if ($LASTEXITCODE -ne 0) {
      throw "netsh failed (exit $LASTEXITCODE): $setting"
    }
  }
}
