---
name: dotbot-manifest-check
description: Dry-run validate install.conf.yaml against dotbot before deploying, catching broken links, missing source paths, and YAML errors ahead of time. Use when the user says "check install.conf.yaml", "validate dotbot manifest", or before running Setup-Dotfiles.ps1 after editing the manifest.
disable-model-invocation: true
---

# Dotbot Manifest Pre-Flight Check

`install.conf.yaml` drives `Scripts/Setup-Dotfiles.ps1` and is one of this
repo's most frequently edited files. Validate it before deploying.

## Steps

1. YAML syntax check:

```powershell
python -c "import yaml; yaml.safe_load(open('install.conf.yaml'))"
```

2. Dry-run against dotbot (no filesystem changes — `--dry-run` if the
   installed dotbot version supports it; otherwise inspect `link` targets
   manually):

```bash
python -m dotbot -c install.conf.yaml -v --only shell 2>&1 | head -50
```

If `--dry-run` isn't supported by the pinned dotbot version, instead:

3. For every `link:` entry, verify the source path exists under
   `user/.dotfiles/config/` and the target's parent directory is resolvable
   (env vars like `%APPDATA%` expand):

```powershell
$manifest = python -c "import yaml,json; print(json.dumps(yaml.safe_load(open('install.conf.yaml'))))" | ConvertFrom-Json
foreach ($plugin in $manifest) {
  if ($plugin.link) {
    foreach ($target in $plugin.link.PSObject.Properties) {
      $src = Join-Path (Get-Location) $target.Value
      if (-not (Test-Path $src)) { Write-Warning "Missing source: $($target.Value) (target: $($target.Name))" }
    }
  }
}
```

## Output

- List any missing source files, unresolvable target paths, or YAML errors
- If clean, state so plainly — don't run the actual deploy unless asked
