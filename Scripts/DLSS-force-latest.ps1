#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "DLSS Force Latest (Administrator)"

Write-Host "Installing: NvidiaProfileInspector . . ."
# check for file
if (-Not (Test-Path -Path "$env:TEMP\Inspector.exe")) {
  # unblock drs files
  $path = "C:\ProgramData\NVIDIA Corporation\Drs"
  Get-ChildItem -Path $path -Recurse | Unblock-File
  # download inspector
  Get-FileFromWeb -URL "https://github.com/FR33THYFR33THY/files/raw/main/Inspector.exe" -File "$env:TEMP\Inspector.exe"
  # enable nvidia legacy sharpen
  reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" /v "EnableGR535" /t REG_DWORD /d "0" /f | Out-Null
  reg add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS" /v "EnableGR535" /t REG_DWORD /d "0" /f | Out-Null
  reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" /v "EnableGR535" /t REG_DWORD /d "0" /f | Out-Null
} else {
  # skip
}
Clear-Host

function New-DLSSInspectorConfig {
  <#
  .SYNOPSIS
      Generates NVIDIA Profile Inspector XML configuration for DLSS settings
  .PARAMETER EnableDLSSOverride
      If $true, enables DLSS-SR override settings; if $false, disables them
  #>
  param([bool]$EnableDLSSOverride = $true)

  $dlssOverrideSettings = if ($EnableDLSSOverride) {
    @"
      <ProfileSetting>
        <SettingNameInfo>Override DLSS-SR presets</SettingNameInfo>
        <SettingID>283385331</SettingID>
        <SettingValue>16777215</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Enable DLSS-SR override</SettingNameInfo>
        <SettingID>283385345</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
"@
  } else {
    ""
  }

  return @"
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables />
    <Settings>
      <ProfileSetting>
        <SettingNameInfo> </SettingNameInfo>
        <SettingID>390467</SettingID>
        <SettingValue>2</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Negative LOD bias</SettingNameInfo>
        <SettingID>1686376</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Trilinear optimization</SettingNameInfo>
        <SettingID>3066610</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync Tear Control</SettingNameInfo>
        <SettingID>5912412</SettingID>
        <SettingValue>2525368439</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred refresh rate</SettingNameInfo>
        <SettingID>6600001</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Maximum pre-rendered frames</SettingNameInfo>
        <SettingID>8102046</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Anisotropic filter optimization</SettingNameInfo>
        <SettingID>8703344</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync</SettingNameInfo>
        <SettingID>11041231</SettingID>
        <SettingValue>1620202130</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Shader disk cache maximum size</SettingNameInfo>
        <SettingID>11306135</SettingID>
        <SettingValue>4294967295</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Quality</SettingNameInfo>
        <SettingID>13510289</SettingID>
        <SettingValue>20</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Anisotropic sample optimization</SettingNameInfo>
        <SettingID>15151633</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Display the VRR Indicator</SettingNameInfo>
        <SettingID>268604728</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Flag to control smooth AFR behavior</SettingNameInfo>
        <SettingID>270198627</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Anisotropic filtering setting</SettingNameInfo>
        <SettingID>270426537</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Power management mode</SettingNameInfo>
        <SettingID>274197361</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Gamma correction</SettingNameInfo>
        <SettingID>276652957</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Mode</SettingNameInfo>
        <SettingID>276757595</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>FRL Low Latency</SettingNameInfo>
        <SettingID>277041152</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Frame Rate Limiter</SettingNameInfo>
        <SettingID>277041154</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Frame Rate Limiter for NVCPL</SettingNameInfo>
        <SettingID>277041162</SettingID>
        <SettingValue>357</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Toggle the VRR global feature</SettingNameInfo>
        <SettingID>278196567</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>VRR requested state</SettingNameInfo>
        <SettingID>278196727</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>G-SYNC</SettingNameInfo>
        <SettingID>279476687</SettingID>
        <SettingValue>4</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Anisotropic filtering mode</SettingNameInfo>
        <SettingID>282245910</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Setting</SettingNameInfo>
        <SettingID>282555346</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
$dlssOverrideSettings      <ProfileSetting>
        <SettingNameInfo>CUDA Sysmem Fallback Policy</SettingNameInfo>
        <SettingID>283962569</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Enable G-SYNC globally</SettingNameInfo>
        <SettingID>294973784</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>OpenGL GDI compatibility</SettingNameInfo>
        <SettingID>544392611</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Threaded optimization</SettingNameInfo>
        <SettingID>549528094</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred OpenGL GPU</SettingNameInfo>
        <SettingID>550564838</SettingID>
        <SettingValue>id,2.0:268410DE,00000100,GF - (400,2,161,24564) @ (0)</SettingValue>
        <ValueType>String</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vulkan/OpenGL present method</SettingNameInfo>
        <SettingID>550932728</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
"@
}

# Main menu loop
while ($true) {
  Show-Menu -Title "DLSS Force Latest Configuration" -Options @(
    "DLSS Force Latest: On"
    "DLSS Force Latest: Off (Default)"
    "DLSS Overlay: On"
    "DLSS Overlay: Off (Default)"
    "Read Only"
    "Inspector"
  )

  Write-Host ""
  Write-Host "DLSSv3 v310.X.X or above = DLSS 4" -ForegroundColor Red
  Write-Host "DLSSv3 v3.X.X  or below = DLSS 3" -ForegroundColor Red
  Write-Host ""

  $choice = Get-MenuChoice -Min 1 -Max 6

  switch ($choice) {
    1 {
      Clear-Host
      Write-Host "DLSS Force Latest: On"
      # revert read only nvdrsdb0.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb0.bin" -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null
      # revert read only nvdrsdb1.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb1.bin" -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null
      # create config for inspector
      $config = New-DLSSInspectorConfig -EnableDLSSOverride $true
      Set-Content -Path "$env:TEMP\DLSSLatestOn.nip" -Value $config -Force
      # import config
      Start-Process -wait "$env:TEMP\Inspector.exe" -ArgumentList "$env:TEMP\DLSSLatestOn.nip"
    }
    2 {
      Clear-Host
      Write-Host "DLSS Force Latest: Off"
      # revert read only nvdrsdb0.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb0.bin" -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null
      # revert read only nvdrsdb1.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb1.bin" -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null
      # create config for inspector
      $config = New-DLSSInspectorConfig -EnableDLSSOverride $false
      Set-Content -Path "$env:TEMP\DLSSLatestOff.nip" -Value $config -Force
      # import config
      Start-Process -wait "$env:TEMP\Inspector.exe" -ArgumentList "$env:TEMP\DLSSLatestOff.nip"
    }
    3 {
      Clear-Host
      reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore" /v "ShowDlssIndicator" /t REG_DWORD /d "1024" /f | Out-Null
      Write-Host "DLSS Overlay: On . . ."
      Wait-ForKeyPress
    }
    4 {
      Clear-Host
      cmd.exe /c "reg delete `"HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore`" /v `"ShowDlssIndicator`" /f >nul 2>&1"
      Write-Host "DLSS Overlay: Off (Default) . . ."
      Wait-ForKeyPress
    }
    5 {
      Clear-Host
      # read only nvdrsdb0.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb0.bin" -Name IsReadOnly -Value $true -ErrorAction SilentlyContinue | Out-Null
      # read only nvdrsdb1.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb1.bin" -Name IsReadOnly -Value $true -ErrorAction SilentlyContinue | Out-Null
      Write-Host "Read Only"
      Write-Host ""
      Write-Host "nvdrsdb0.bin & nvdrsdb1.bin set to read only"
      Wait-ForKeyPress -Message "Press any key to continue . . ."
    }
    6 {
      Clear-Host
      Write-Host "Inspector"
      # revert read only nvdrsdb0.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb0.bin" -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null
      # revert read only nvdrsdb1.bin
      Set-ItemProperty -Path "$env:SystemDrive\ProgramData\NVIDIA Corporation\Drs\nvdrsdb1.bin" -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null
      # open inspector
      Start-Process -wait "$env:TEMP\Inspector.exe"
    }
  }
}
