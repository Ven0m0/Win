#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\Common.ps1"

# === QoS Registry Implementation (Home/Pro compatible) ===
$qosPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS'
if (-not (Test-Path -Path $qosPath)) {
  $null = New-Item -Path $qosPath -Force
}

$qosGames = @{
  'ArcRaiders' = 'PioneerGame.exe'
  'BlackOps6'  = 'cod24-cod.exe'
  'Fortnite'   = 'FortniteClient-Win64-Shipping.exe'
}

foreach ($game in $qosGames.GetEnumerator()) {
  $gamePath = Join-Path -Path $qosPath -ChildPath $game.Name
  if (-not (Test-Path -Path $gamePath)) {
    $null = New-Item -Path $gamePath -Force
  }

  $props = @{
    'Version'                 = '1.0'
    'Application Name'        = $game.Value
    'Protocol'                = '*'
    'Local Port'              = '*'
    'Remote Port'             = '*'
    'Local IP'                = '*'
    'Remote IP'               = '*'
    'Local IP Prefix Length'  = '*'
    'Remote IP Prefix Length' = '*'
    'DSCP Value'              = '46'
    'Throttle Rate'           = '-1'
  }

  foreach ($prop in $props.GetEnumerator()) {
    Set-ItemProperty -Path $gamePath -Name $prop.Name -Value $prop.Value -Type String
  }
}

& gpupdate /force

# === Windows Defender Exclusions ===
Add-MpPreference -ExclusionProcess 'node.exe', 'clang.exe', 'rustc.exe', 'cargo.exe', 'bun.exe', 'bunx.exe', 'sccache.exe'
Add-MpPreference -ExclusionProcess 'PioneerGame.exe', 'cod24-cod.exe', 'FortniteClient-Win64-Shipping.exe'
