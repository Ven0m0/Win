Set-Location $PSScriptRoot

$files = @(
    'DeviceCleanup.exe',
    'DeviceCleanup.txt',
    'DriveCleanup.exe',
    'DriveCleanup.txt',
    'DeviceCleanup.zip',
    'DriveCleanup.zip'
)

$files | ForEach-Object {
    Remove-Item $_ -Force -ErrorAction SilentlyContinue
}

Invoke-WebRequest 'https://www.uwe-sieber.de/files/DeviceCleanup_x64.zip' -OutFile 'DeviceCleanup.zip'
Invoke-WebRequest 'https://www.uwe-sieber.de/files/DriveCleanup.zip' -OutFile 'DriveCleanup.zip'

Start-Sleep 1

$sevenZip = Get-Command 7z, 7za -ErrorAction SilentlyContinue | Select-Object -First 1

function Expand-ArchiveCompat {
    param(
        [Parameter(Mandatory)]
        [string]$Zip
    )

    if ($sevenZip) {
        & $sevenZip.Source x '-y' "-o$PSScriptRoot" $Zip | Out-Null
        return
    }

    if (Get-Command tar -ErrorAction SilentlyContinue) {
        tar -xf $Zip
        return
    }

    Expand-Archive -Path $Zip -DestinationPath $PSScriptRoot -Force
}

Expand-ArchiveCompat 'DeviceCleanup.zip'

Start-Sleep 1

Remove-Item 'DeviceCleanup.zip', 'DeviceCleanup.txt' -Force -ErrorAction SilentlyContinue

Expand-ArchiveCompat 'DriveCleanup.zip'

Start-Sleep 1

Remove-Item 'Win32' -Recurse -Force -ErrorAction SilentlyContinue

if (Test-Path 'x64') {
    Move-Item 'x64\*' . -Force
    Remove-Item 'x64' -Recurse -Force -ErrorAction SilentlyContinue
}

Remove-Item 'DriveCleanup.zip', 'DriveCleanup.txt' -Force -ErrorAction SilentlyContinue