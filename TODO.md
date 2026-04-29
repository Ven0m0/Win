### 1
extend py-psscriptanalyzer integration and include it in @mise.toml

```bash
# format
py-psscriptanalyzer --format example.ps1
# lint recursively
py-psscriptanalyzer --recursive
```
also ensure the pre-commit hooks of py-psscriptanalyzer work correctly

### 2

add to system fix:
- https://github.com/ShadowWhisperer/Fix-WinUpdates

### 3 winget fix

from https://schneegans.de/windows/unattend-generator/samples

```pwsh
if( [System.Environment]::OSVersion.Version.Build -lt 26100 ) {
    'This script requires Windows 11 24H2 or later.' | Write-Warning;
    return;
}
$timeout = [datetime]::Now.AddMinutes( 5 );
$exe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe";

while( $true ) {
    if( $exe | Test-Path ) {
        & $exe install --exact --id Mozilla.Firefox --silent --accept-package-agreements --accept-source-agreements --source winget --scope machine;
        return;
    }
    if( [datetime]::Now -gt $timeout ) {
        "File '${exe}' does not exist." | Write-Warning;
        return;
    }
    "Waiting for '${exe}' to become available..." | Write-Host;
    Start-Sleep -Seconds 1;
}
```
