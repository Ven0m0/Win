# dns-benchmark.ps1

Benchmarks DNS resolvers: Cloudflare, Cloudflare Malware-blocking and AdGuard DNS, each over IPv4
and IPv6 (12 servers). Read-only, no admin needed.

## Usage

```powershell
.\Scripts\dns-benchmark.ps1                       # table + objects
.\Scripts\dns-benchmark.ps1 -Rounds 2 -PassThru | Export-Csv dns.csv -NoTypeInformation
.\Scripts\dns-benchmark.ps1 -AddServer 9.9.9.9, 2620:fe::fe
.\Scripts\dns-benchmark.ps1 -Server 9.9.9.9 -Domain example.com
```

| Parameter | Default | Meaning |
| --------- | ------- | ------- |
| `-Domain` | 10 popular domains | Names to resolve (A records) |
| `-Rounds` | 5 | Measured rounds per domain; one extra warm-up round per server is not counted |
| `-AddServer` | none | Extra resolver addresses benchmarked alongside the built-in list (Provider = `Custom`) |
| `-Server` | built-in list | Replace the built-in list with only these addresses |

## Output

Two tables: per server, then one row per provider (all its IPv4 + IPv6 servers pooled:
`Provider, MinMs, MedianMs, AvgMs, MaxMs`). Objects sorted by median: `Provider, Server, Family, MinMs, MedianMs, AvgMs, MaxMs, FailPct, Status`.
A server where every measured query fails (for example no IPv6 route) has `Status = unreachable`
and sorts last. The per-query timeout is `Resolve-DnsName -QuickTimeout` (about 1 s); the cmdlet
has no configurable timeout. Only plain DNS (UDP/TCP 53) is measured, not DoH/DoT.
