#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dot-sourcing loads the functions without running the benchmark (InvocationName guard).
    . "$PSScriptRoot/../Scripts/dns-benchmark.ps1"
}

Describe 'Send-DnsQuery' {
    BeforeAll {
        # Bound but never answers, so every query to it must time out.
        $script:silent = [System.Net.Sockets.UdpClient]::new([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback, 0))
        $script:silentPort = $script:silent.Client.LocalEndPoint.Port
    }

    AfterAll {
        $script:silent.Dispose()
    }

    It 'returns $null within the timeout when nothing replies' {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Send-DnsQuery -Address '127.0.0.1' -Name 'example.com' -Port $script:silentPort -TimeoutMs 200
        $sw.Stop()
        $r | Should -BeNullOrEmpty
        $sw.Elapsed.TotalMilliseconds | Should -BeLessThan 1000
    }
}

Describe 'Invoke-DnsBenchmark' {
    BeforeEach {
        Mock Write-Info { }
        Mock Write-Warn { }
    }

    It 'interleaves servers: warm-up plus measured queries, all samples recorded' {
        Mock Send-DnsQuery { 10.0 }
        $r = @(Invoke-DnsBenchmark -Domain 'a.com', 'b.com' -Rounds 2 -Server '1.1.1.1', '8.8.8.8')
        # 2 servers x 2 domains x (1 warm-up + 2 rounds) = 12 calls
        Should -Invoke Send-DnsQuery -Times 12 -Exactly
        $r.Count | Should -Be 2
        foreach ($row in $r) {
            $row.Samples.Count | Should -Be 4
            $row.FailPct | Should -Be 0
            $row.Status | Should -Be 'ok'
        }
    }

    It 'sorts by median with unreachable servers last' {
        Mock Send-DnsQuery {
            switch ($Address) { '1.1.1.1' { 30.0 } '8.8.8.8' { 10.0 } default { $null } }
        }
        $r = @(Invoke-DnsBenchmark -Domain 'a.com' -Rounds 1 -Server '1.1.1.1', '9.9.9.9', '8.8.8.8')
        $r.Server | Should -Be @('8.8.8.8', '1.1.1.1', '9.9.9.9')
    }

    It 'queries a dead server only during warm-up' {
        Mock Send-DnsQuery { if ($Address -eq '9.9.9.9') { $null } else { 10.0 } }
        $r = @(Invoke-DnsBenchmark -Domain 'a.com', 'b.com' -Rounds 3 -Server '1.1.1.1', '9.9.9.9')
        Should -Invoke Send-DnsQuery -Times 2 -Exactly -ParameterFilter { $Address -eq '9.9.9.9' }
        $r[-1].Server | Should -Be '9.9.9.9'
        $r[-1].Status | Should -Be 'unreachable'
        $r[-1].MedianMs | Should -BeNullOrEmpty
        $r[-1].FailPct | Should -Be 100
    }

    It 'computes FailPct from partial failures' {
        $script:n = 0
        Mock Send-DnsQuery {
            if ($Address -ne '8.8.8.8') { return 10.0 }
            $script:n++
            # calls 1-2 are warm-up; measured calls are 3..6, every second one fails (4 and 6)
            if ($script:n -gt 2 -and $script:n % 2 -eq 0) { $null } else { 10.0 }
        }
        $r = @(Invoke-DnsBenchmark -Domain 'a.com', 'b.com' -Rounds 2 -Server '1.1.1.1', '8.8.8.8')
        $row = $r | Where-Object { $_.Server -eq '8.8.8.8' }
        $row.FailPct | Should -Be 50
        $row.Samples.Count | Should -Be 2
    }

    It 'detects IPv6' {
        Mock Send-DnsQuery { 5.0 }
        $r = @(Invoke-DnsBenchmark -Domain 'a.com' -Rounds 1 -Server '2606:4700:4700::1111', '1.1.1.1')
        ($r | Where-Object { $_.Server -eq '2606:4700:4700::1111' }).Family | Should -Be 'IPv6'
        ($r | Where-Object { $_.Server -eq '1.1.1.1' }).Family | Should -Be 'IPv4'
    }

    It 'appends -AddServer to the defaults' {
        Mock Send-DnsQuery { 1.0 }
        $r = @(Invoke-DnsBenchmark -Domain 'a.com' -Rounds 1 -AddServer '9.9.9.9')
        $r.Count | Should -Be 13
        $r.Server | Should -Contain '9.9.9.9'
    }

    It 'ships 12 default servers' {
        $script:DefaultServers.Count | Should -Be 12
    }
}

Describe 'Get-LatencyStats' {
    It 'computes median, P90 and population jitter' {
        $r = Get-LatencyStats -Time (1..10)
        $r.MedianMs | Should -Be 5.5
        $r.P90Ms | Should -Be 9
        $r.JitterMs | Should -Be 2.9
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
        $r[0].P90Ms | Should -Be 100
        $r[0].AvgMs | Should -Be 40
        $r[0].MaxMs | Should -Be 100
        $r[0].JitterMs | Should -Be 35.4
    }
}
