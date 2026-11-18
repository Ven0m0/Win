#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dot-sourcing loads the functions without running the benchmark (InvocationName guard).
    . "$PSScriptRoot/../Scripts/dns-benchmark.ps1"
}

Describe 'Measure-DnsServer' {
    It 'skips the warm-up round and reports stats over measured queries' {
        Mock Resolve-DnsName { Start-Sleep -Milliseconds 5 }
        $r = Measure-DnsServer -Provider 'T' -Address '1.1.1.1' -Domain 'a.com', 'b.com' -Rounds 2
        Should -Invoke Resolve-DnsName -Times 6 -Exactly
        $r.Status | Should -Be 'ok'
        $r.Family | Should -Be 'IPv4'
        $r.FailPct | Should -Be 0
        $r.MinMs | Should -BeLessOrEqual $r.MedianMs
        $r.MedianMs | Should -BeLessOrEqual $r.MaxMs
    }

    It 'counts failures and detects IPv6' {
        $script:n = 0
        Mock Resolve-DnsName { $script:n++; if ($script:n -eq 2 -or $script:n -eq 3) { throw 'timeout' } }
        # 1 domain, 2 rounds: call 1 warm-up, calls 2-3 measured (both fail) -> 100%
        $r = Measure-DnsServer -Provider 'T' -Address '2606:4700:4700::1111' -Domain 'a.com' -Rounds 2
        $r.Family | Should -Be 'IPv6'
        $r.FailPct | Should -Be 100
        $r.Status | Should -Be 'unreachable'
        $r.MedianMs | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-DnsBenchmark' {
    It 'sorts by median with unreachable servers last' {
        Mock Write-Info { }
        Mock Write-Warn { }
        Mock Measure-DnsServer {
            $m = @{ '1.1.1.1' = 30; '9.9.9.9' = $null; '8.8.8.8' = 10 }[$Address]
            [pscustomobject]@{ Server = $Address; MedianMs = $m; Status = $(if ($null -eq $m) { 'unreachable' } else { 'ok' }) }
        }
        $r = Invoke-DnsBenchmark -Domain 'a.com' -Rounds 1 -Server '1.1.1.1', '9.9.9.9', '8.8.8.8'
        $r.Server | Should -Be @('8.8.8.8', '1.1.1.1', '9.9.9.9')
    }

    It 'appends -AddServer to the defaults' {
        Mock Write-Info { }
        Mock Write-Warn { }
        Mock Measure-DnsServer { [pscustomobject]@{ Server = $Address; MedianMs = 1; Status = 'ok' } }
        $r = Invoke-DnsBenchmark -Domain 'a.com' -Rounds 1 -AddServer '9.9.9.9'
        $r.Count | Should -Be 13
        $r.Server | Should -Contain '9.9.9.9'
    }

    It 'ships 12 default servers' {
        $script:DefaultServers.Count | Should -Be 12
    }
}

Describe 'Get-ProviderSummary' {
    It 'pools IPv4 and IPv6 samples into one row per provider' {
        $rows = @(
            [pscustomobject]@{ Provider = 'A'; Samples = [double[]](10, 20) }
            [pscustomobject]@{ Provider = 'A'; Samples = [double[]](30, 100) }
            [pscustomobject]@{ Provider = 'B'; Samples = [double[]](50) }
        )
        $r = @(Get-ProviderSummary -Result $rows)
        $r.Count | Should -Be 2
        $r[0].Provider | Should -Be 'A'
        $r[0].MinMs | Should -Be 10
        $r[0].MedianMs | Should -Be 25
        $r[0].AvgMs | Should -Be 40
        $r[0].MaxMs | Should -Be 100
    }
}
