#Requires -Version 5.1
[CmdletBinding()]
param(
  [double]$Increment = 0.002,
  [double]$Start = 0.5,
  [double]$End = 0.8,
  [int]$Samples = 20
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

function Invoke-TimerBenchmark {
  [CmdletBinding()]
  param(
    [double]$Start,
    [double]$End,
    [double]$Increment,
    [int]$Samples
  )

  Request-AdminElevation

  $iterations = ($End - $Start) / $Increment
  $totalMs = $iterations * 102 * $Samples

  Write-Host "Approximate worst-case estimated time for completion: $([math]::Round($totalMs / 6E4, 2))mins"
  Write-Host "Worst-case is determined by assuming Sleep(1) = ~2ms with 1ms Timer Resolution"
  Write-Host "Start: $($Start)ms, End: $($End)ms, Increment: $($Increment)ms, Samples: $($Samples)"

  Stop-Process -Name 'SetTimerResolution' -ErrorAction SilentlyContinue

  foreach ($dependency in @('SetTimerResolution.exe', 'MeasureSleep.exe')) {
    if (-not (Test-Path -Path "$PSScriptRoot\$dependency")) {
      Write-Error "error: $dependency not found in script directory"
      return
    }
  }

  $resultsPath = "$PSScriptRoot\results.txt"
  'RequestedResolutionMs,DeltaMs,STDEV' | Out-File -FilePath $resultsPath

  for ($i = $Start; $i -le $End; $i += $Increment) {
    Write-Host "info: benchmarking $($i)ms"

    Start-Process -FilePath "$PSScriptRoot\SetTimerResolution.exe" -ArgumentList @('--resolution', ($i * 1E4), '--no-console')

    # A small delay is required after setting the resolution to avoid unexpected results
    Start-Sleep -Seconds 1

    $output = & "$PSScriptRoot\MeasureSleep.exe" --samples $Samples
    $outputLines = $output -split "`n"
    $avg = $null
    $stdev = $null

    foreach ($line in $outputLines) {
      if ($line -match 'Avg: (.+)') {
        $avg = $Matches[1]
      } elseif ($line -match 'STDEV: (.+)') {
        $stdev = $Matches[1]
      }
    }

    "$($i), $([math]::Round([double]$avg, 3)), $($stdev)" | Out-File -FilePath $resultsPath -Append

    Stop-Process -Name 'SetTimerResolution' -ErrorAction SilentlyContinue
  }

  Write-Host "info: results saved in $resultsPath"
}

Invoke-TimerBenchmark -Start $Start -End $End -Increment $Increment -Samples $Samples
