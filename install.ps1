# Claude Code Rainmeter widgets - installer helper.
# Copies both skins into your Rainmeter Skins folder and installs the
# ClaudeSessions log hook, then prints the settings.json snippet to paste.
# It does NOT edit settings.json, and does NOT register the ClaudeUsage task
# (run scripts\setup-usage-task.ps1 for that) - both are opt-in.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$skins = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'

Write-Host "Claude Code Rainmeter widgets - installer" -ForegroundColor Cyan
Write-Host ""

# 1) skins
foreach ($name in 'ClaudeSessions', 'ClaudeUsage') {
  $dst = Join-Path $skins $name
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item (Join-Path $root "$name\*") $dst -Recurse -Force
  Write-Host "[ok] skin  -> $dst" -ForegroundColor Green
}

# 2) ClaudeSessions hook
$hookDir = Join-Path $env:USERPROFILE '.claude\hooks'
$hookDst = Join-Path $hookDir 'session-logger.js'
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
Copy-Item (Join-Path $root 'hooks\session-logger.js') $hookDst -Force
Write-Host "[ok] hook  -> $hookDst" -ForegroundColor Green

# 3) settings.json snippet for the hook
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
$nodeCmd = if ($node) { 'node' } else { 'C:\Program Files\nodejs\node.exe' }
$argPath = $hookDst.Replace('\', '\\')
$settings = Join-Path $env:USERPROFILE '.claude\settings.json'

Write-Host ""
Write-Host "== ClaudeSessions ==" -ForegroundColor Cyan
Write-Host "Merge this into $settings (under a top-level `"hooks`" key), then restart Claude Code:" -ForegroundColor Yellow
$snippet = @"
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "$nodeCmd", "args": ["$argPath", "start"], "timeout": 15 } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "command": "$nodeCmd", "args": ["$argPath", "end"], "timeout": 30 } ] }
    ]
  }
"@
Write-Host $snippet -ForegroundColor Gray
if (-not $node) { Write-Host "(node not on PATH; snippet uses the default path - adjust if needed.)" -ForegroundColor DarkYellow }

Write-Host ""
Write-Host "== ClaudeUsage (optional) ==" -ForegroundColor Cyan
Write-Host "Reads your Claude Code OAuth token and calls an UNDOCUMENTED usage endpoint - see the README warning." -ForegroundColor DarkYellow
Write-Host "To enable it, register the 5-minute polling task:" -ForegroundColor Yellow
Write-Host "    powershell -NoProfile -ExecutionPolicy Bypass -File `"$($root)\scripts\setup-usage-task.ps1`"" -ForegroundColor Gray

Write-Host ""
Write-Host "Finally: in Rainmeter, Refresh all, then load ClaudeSessions / ClaudeUsage from Manage." -ForegroundColor Yellow
