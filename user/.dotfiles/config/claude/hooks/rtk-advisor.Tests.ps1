#Requires -Version 5.1
# Feeds PreToolUse payloads to rtk-advisor.ps1 the way Claude Code does (JSON on stdin).

BeforeAll {
  $script:Hook = Join-Path -Path $PSScriptRoot -ChildPath 'rtk-advisor.ps1'

  function Invoke-Hook ($Tool, $Command) {
    $payload = @{ tool_name = $Tool; tool_input = @{ command = $Command; timeout = 5000 } } |
      ConvertTo-Json -Compress
    $out = ($payload | pwsh -nop -nol -f $script:Hook | Out-String).Trim()
    if ($out) { ($out | ConvertFrom-Json).hookSpecificOutput } else { $null }
  }
}

Describe 'rtk-advisor pipe rewrite' {
  It 'rewrites cd-prefixed rg with a quoted alternation piped to head' {
    $r = Invoke-Hook 'Bash' "cd /c/x && rg -n 'a|b' . | head -20"
    $r.updatedInput.command | Should -Be "cd /c/x && rtk rg -n 'a|b' . | head -20"
    $r.updatedInput.timeout | Should -Be 5000
  }

  It 'keeps 2>&1 before the pipe' {
    $r = Invoke-Hook 'Bash' 'git show --stat HEAD 2>&1 | tail -5'
    $r.updatedInput.command | Should -Be 'rtk git show --stat HEAD 2>&1 | tail -5'
  }

  It 'does not rewrite when a later stage computes on the output' {
    $r = Invoke-Hook 'Bash' 'rg -n foo . | wc -l'
    $r.updatedInput | Should -BeNullOrEmpty
    $r.additionalContext | Should -Match 'Piping disables rtk'
  }

  It 'does not rewrite command substitution' {
    $r = Invoke-Hook 'Bash' 'echo $(rg foo) | head'
    $r.updatedInput | Should -BeNullOrEmpty
  }

  It 'does not rewrite for the PowerShell tool' {
    $r = Invoke-Hook 'PowerShell' 'rg -n foo . | head -5'
    $r.updatedInput | Should -BeNullOrEmpty
  }

  It 'stays silent when the first stage is already rtk' {
    Invoke-Hook 'Bash' 'rtk gain --history | head -5' | Should -BeNullOrEmpty
  }

  It 'stays silent for commands rtk hook already rewrites' {
    Invoke-Hook 'Bash' 'git status' | Should -BeNullOrEmpty
  }
}
