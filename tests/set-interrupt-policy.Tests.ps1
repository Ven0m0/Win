#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/set-interrupt-policy.ps1"
}

Describe 'Get-InterruptPolicyTarget' {
    It 'spreads GPU and NIC interrupts' {
        Get-InterruptPolicyTarget -Class Display -FriendlyName 'NVIDIA GeForce' | Should -Be 5
        Get-InterruptPolicyTarget -Class Net -FriendlyName 'Intel I225-V' | Should -Be 5
    }

    It 'keeps NVMe and USB host controllers close' {
        Get-InterruptPolicyTarget -Class SCSIAdapter -FriendlyName 'Standard NVM Express Controller' | Should -Be 1
        Get-InterruptPolicyTarget -Class USB -FriendlyName 'USB xHCI Compliant Host Controller' | Should -Be 1
    }

    It 'leaves everything else alone' {
        Get-InterruptPolicyTarget -Class SCSIAdapter -FriendlyName 'SATA AHCI Controller' | Should -BeNullOrEmpty
        Get-InterruptPolicyTarget -Class USB -FriendlyName 'USB Root Hub' | Should -BeNullOrEmpty
        Get-InterruptPolicyTarget -Class Mouse -FriendlyName 'HID mouse' | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-InterruptPolicyRestore' {
    It 'rewrites saved values and deletes values that did not exist' {
        $file = Join-Path -Path $TestDrive -ChildPath 'b.json'
        @(
            [pscustomobject]@{ InstanceId = 'PCI\A'; Current = 1 },
            [pscustomobject]@{ InstanceId = 'PCI\B'; Current = $null }
        ) | ConvertTo-Json | Set-Content -Path $file
        Mock Set-RegistryValue { }
        Mock Remove-RegistryValue { }
        Mock Write-Info { }
        Invoke-InterruptPolicyRestore -Path $file
        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter { $Data -eq '1' }
        Should -Invoke Remove-RegistryValue -Times 1 -Exactly
    }

    It 'throws when the backup is missing' {
        { Invoke-InterruptPolicyRestore -Path (Join-Path -Path $TestDrive -ChildPath 'nope.json') } |
            Should -Throw -ExpectedMessage '*Backup not found*'
    }
}

Describe 'Invoke-InterruptPolicyApply' {
    It 'keeps the original value when applied twice' {
        $file = Join-Path -Path $TestDrive -ChildPath 'apply.json'
        Mock Set-RegistryValue { }
        Mock Write-Info { }
        $first = @([pscustomobject]@{ InstanceId = 'PCI\A'; Current = 2; Target = 5 })
        Invoke-InterruptPolicyApply -Plan $first -Path $file
        $second = @([pscustomobject]@{ InstanceId = 'PCI\A'; Current = 5; Target = 5 })
        Invoke-InterruptPolicyApply -Plan $second -Path $file
        @(Get-Content -LiteralPath $file -Raw | ConvertFrom-Json)[0].Current | Should -Be 2
    }
}
