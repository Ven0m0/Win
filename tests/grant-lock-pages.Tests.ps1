#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# Top-level script (no dispatcher guard); invoked with '&' after secedit, file writes, elevation,
# and the closing Read-Host prompt are mocked.
Describe 'grant-lock-pages.ps1' {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/grant-lock-pages.ps1'
    $script:userSid = ([Security.Principal.NTAccount]"$env:USERNAME").Translate(
      [Security.Principal.SecurityIdentifier]).Value
    function secedit { }
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share data through this reference object.
    $lpimState = @{
      Inf = @('[Unicode]', 'Unicode=yes', '[Privilege Rights]', 'SeLockMemoryPrivilege = *S-1-5-32-544')
    }

    Mock Request-AdminElevation { }
    Mock secedit { }
    Mock New-Item { }
    Mock Get-Content { $lpimState.Inf }
    Mock Set-Content { }
    Mock Read-Host { }
    Mock Write-Info { }
    Mock Write-Success { }
    Mock Write-Warn { }
  }

  It 'Appends the current user to an existing privilege line' {
    & $scriptPath

    Should -Invoke Set-Content -Times 1 -Exactly -ParameterFilter {
      $Value -contains "SeLockMemoryPrivilege = *S-1-5-32-544,*$userSid" -and
      # secedit needs UTF-16; PS 5.1 binds an enum, PS 7 an Encoding object.
      ("$Encoding" -eq 'Unicode' -or $Encoding.WebName -eq 'utf-16')
    }
    Should -Invoke secedit -Times 1 -Exactly -ParameterFilter { $args[0] -eq '/configure' }
  }

  It 'Adds the privilege line under [Privilege Rights] when it is missing' {
    $lpimState.Inf = @('[Unicode]', 'Unicode=yes', '[Privilege Rights]', 'SeBackupPrivilege = *S-1-5-32-544')

    & $scriptPath

    Should -Invoke Set-Content -Times 1 -Exactly -ParameterFilter {
      $index = [array]::IndexOf([string[]]$Value, '[Privilege Rights]')
      $Value[$index + 1] -eq "SeLockMemoryPrivilege = *$userSid" -and $Value.Count -eq 5
    }
  }

  It 'Leaves the policy untouched when the user already holds the privilege' {
    $lpimState.Inf = @('[Privilege Rights]', "SeLockMemoryPrivilege = *S-1-5-32-544,*$userSid")

    & $scriptPath

    Should -Invoke Set-Content -Times 0
    Should -Invoke secedit -Times 0 -ParameterFilter { $args[0] -eq '/configure' }
    Should -Invoke Write-Success -Times 1 -Exactly -ParameterFilter { $Text -like 'Already granted*' }
  }

  It 'Still grants when another holder SID only starts with the user SID' {
    $lpimState.Inf = @('[Privilege Rights]', "SeLockMemoryPrivilege = *${userSid}1")

    & $scriptPath

    Should -Invoke Set-Content -Times 1 -Exactly -ParameterFilter {
      $Value -contains "SeLockMemoryPrivilege = *${userSid}1,*$userSid"
    }
  }

  It 'Exports only the USER_RIGHTS area before editing' {
    & $scriptPath

    Should -Invoke secedit -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq '/export' -and ($args -join ' ') -like '*/areas USER_RIGHTS*'
    }
  }
}
