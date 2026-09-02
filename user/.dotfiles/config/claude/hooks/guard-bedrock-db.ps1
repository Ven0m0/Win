#Requires -Version 5.1
<#
.SYNOPSIS
  PreToolUse guard for Minecraft Bedrock LevelDB world files.
.DESCRIPTION
  Blocks Edit/Write against LevelDB internal binary files (*.ldb, *.log, CURRENT,
  LOCK, MANIFEST-*, level.dat[.old]) inside a Bedrock world's db/ folder or root -
  these are engine-owned binary formats, never hand-edited as text. Blocks Bash
  commands that look like they'd delete/truncate/overwrite those same paths.
  Reads/writes of chunk data should go through amulet-leveldb (see the
  bedrock-db-query and bedrock-world-backup skills), not Edit/Write/shell redirection.
#>

$ErrorActionPreference = 'Stop'

$dbFilePattern = '(?i)[\\/]db[\\/][^\\/]*\.(ldb|log)$|(?i)(^|[\\/])(CURRENT|LOCK|MANIFEST-\d+)$|(?i)level\.dat(_old)?$'
$destructivePattern = '(?i)\b(rm|del|Remove-Item)\b[^\r\n]*([\\/]db(?:[\\/]|$)|level\.dat)'

try {
  $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
  exit 0
}

$toolName = $payload.tool_name

if ($toolName -in @('Edit', 'Write')) {
  $filePath = $payload.tool_input.file_path
  if ($filePath -match $dbFilePattern) {
    Write-Error "Blocked: direct $toolName on Bedrock LevelDB internal file '$filePath'. This is a binary engine file - never hand-edit. Use the bedrock-world-backup skill to snapshot, then bedrock-db-query (amulet-leveldb) to read/write chunk data."
    exit 1
  }
}

if ($toolName -eq 'Bash') {
  $command = $payload.tool_input.command
  if ($command -match $destructivePattern) {
    Write-Error "Blocked: destructive command against a Bedrock world file. Snapshot with the bedrock-world-backup skill before deleting/overwriting db/ contents or level.dat."
    exit 1
  }
}

exit 0
