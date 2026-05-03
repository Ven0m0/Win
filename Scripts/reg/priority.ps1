#Requires -Version 5.1
#Requires -RunAsAdministrator

; === QoS PowerShell equivalent ===
New-NetQosPolicy -Name "ArcRaiders" -AppPathNameMatchCondition "PioneerGame.exe" -DSCPAction 46
New-NetQosPolicy -Name "BlackOps6" -AppPathNameMatchCondition "cod24-cod.exe" -DSCPAction 46
New-NetQosPolicy -Name "Fortnite" -AppPathNameMatchCondition "FortniteClient-Win64-Shipping.exe" -DSCPAction 46
gpupdate /force

; === Windows Defender Exclusions ===
Add-MpPreference -ExclusionProcess "node.exe","clang.exe","rustc.exe","cargo.exe","bun.exe","bunx.exe","sccache.exe"
Add-MpPreference -ExclusionProcess "PioneerGame.exe","cod24-cod.exe","FortniteClient-Win64-Shipping.exe"
