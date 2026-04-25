$file = "Scripts/Common.ps1"
$bytes = [System.IO.File]::ReadAllBytes($file)
$content = [System.IO.File]::ReadAllText($file, [System.Text.UTF8Encoding]::new($true))
if ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  $content = $content.Substring(1)
}
$lines = $content -split "\r?\n"
$issues = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i].Length -gt 120 -and $lines[$i] -notmatch '^\s*#') {
    $issues += "[$file]:$($i+1): Line exceeds 120 characters ($($lines[$i].Length))"
  }
}
$issues
