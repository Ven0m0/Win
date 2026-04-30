# Optimize-Repository

**Category:** Maintenance / Optimization
**Scope:** Improve repository performance and maintainability

## Synopsis

Analyze the repository for dead code, duplicate logic, unused dependencies, and structural inefficiencies; produce actionable consolidation recommendations.

## Description

This workflow command performs a repository-wide optimization analysis:

1. **Dead code analysis** — Identify functions, scripts, or config files that are unreferenced or obsolete using `grep` and `glob`
2. **Duplicate detection** — Find repeated logic across scripts that should be consolidated into `Scripts/Common.ps1`
3. **Dependency review** — Check `install.conf.yaml`, winget package lists, and module imports for unused or redundant dependencies
4. **Consolidation suggestions** — Recommend merging similar scripts, extracting shared helpers, or removing stale config files
5. **Size and complexity check** — Flag oversized scripts or functions that exceed maintainability thresholds

## Steps

```bash
# 1. List all scripts and count references
glob Scripts/**/*.ps1
grep -r 'script-name' Scripts/ --include='*.ps1' | wc -l

# 2. Find duplicate patterns (e.g., repeated registry helper blocks)
grep -ri 'New-Item -Path.*-Force' Scripts/

# 3. Check for unused config files
glob user/.dotfiles/config/**/* | xargs -I {} grep -r "$(basename {})" Scripts/ install.conf.yaml

# 4. Review Common.ps1 coverage
grep -ri 'function\s+' Scripts/Common.ps1

# 5. Check script sizes
find Scripts/ -name '*.ps1' -exec wc -l {} + | sort -n
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Path` | String | `'.'` | Repository root to analyze |
| `-OutputFile` | String | `'./optimization-report.md'` | Path for the recommendations report |
| `-MinLines` | Int | `300` | Flag scripts larger than this line count |
| `-IncludeConfig` | Switch | False | Include config files in dead-code analysis |

## Usage

```powershell
# Full repository optimization analysis
.\Optimize-Repository.ps1

# Analyze only Scripts/ directory
.\Optimize-Repository.ps1 -Path Scripts/

# Include config files in analysis
.\Optimize-Repository.ps1 -IncludeConfig

# Custom size threshold
.\Optimize-Repository.ps1 -MinLines 200
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Analysis completed (issues may still be present) |
| `1` | Execution error |

## Notes

- This markdown file is Kilo command reference only. Implement as `Scripts/Optimize-Repository.ps1` if needed.
- Use `grep`, `glob`, and `read` tools during interactive Kilo sessions to perform these analyses.
- Expected output is an optimization recommendations markdown report with priority ratings.
- Never delete files automatically; recommendations require human review before action.

## Related

- `Scripts/Common.ps1` — shared helper consolidation target
- `install.conf.yaml` — dependency manifest
- `Audit-Security.md` — security-focused audit
- `Review-Code.md` — per-change code review
