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
| `-Rounds` | 10 | Measured rounds per domain (100 samples per server with the default domains); the warm-up pass is not counted |
| `-TimeoutMs` | 1000 | Per-query timeout in ms (100-10000) |
| `-AddServer` | none | Extra resolver addresses benchmarked alongside the built-in list (Provider = `Custom`) |
| `-Server` | built-in list | Replace the built-in list with only these addresses |

## Method

- Each query is a raw UDP DNS A query sent over a .NET socket (no `Resolve-DnsName` overhead or
  jitter). The timer covers only send + receive; socket setup is outside it. Replies with a
  mismatched ID are ignored and a non-zero RCODE counts as a failure.
- Servers are interleaved: every round queries each domain (shuffled per round) against every live
  server (shuffled per domain), so network drift affects all servers equally.
- A warm-up pass (each domain once per server) is not counted. A server with no warm-up success is
  marked `unreachable` and skipped, so a dead server costs one timeout per domain, not the whole run.
- Only plain DNS over UDP 53 is measured: no TCP retry on truncated replies, no DoH/DoT.

## Output

Two tables: per server, then one row per provider (all its IPv4 + IPv6 servers pooled:
`Provider, MinMs, MedianMs, P90Ms, AvgMs, MaxMs, JitterMs`). Objects sorted by median, then P90:
`Provider, Server, Family, MinMs, MedianMs, P90Ms, AvgMs, MaxMs, JitterMs, FailPct, Status`.
`P90Ms` is the nearest-rank 90th percentile; `JitterMs` is the population standard deviation.
A server that never answers (for example no IPv6 route) has `Status = unreachable`, `FailPct = 100`
and sorts last.
