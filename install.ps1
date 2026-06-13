# Claude Sessions widget — installer helper.
# Copies the skin and the session-logger hook into place, then prints the
# settings.json snippet to paste. Does NOT edit settings.json automatically.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$skinDst = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins\ClaudeSessions'
$hookDir = Join-Path $env:USERPROFILE '.claude\hooks'
$hookDst = Join-Path $hookDir 'session-logger.js'

Write-Host "Claude Sessions — installer" -ForegroundColor Cyan
Write-Host ""

# 1) skin
New-Item -ItemType Directory -Force -Path $skinDst | Out-Null
Copy-Item (Join-Path $root 'ClaudeSessions\*') $skinDst -Recurse -Force
Write-Host "[ok] skin  -> $skinDst" -ForegroundColor Green

# 2) hook
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
Copy-Item (Join-Path $root 'hooks\session-logger.js') $hookDst -Force
Write-Host "[ok] hook  -> $hookDst" -ForegroundColor Green

# 3) settings.json snippet (resolve node for the user)
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
$nodeCmd = if ($node) { 'node' } else { 'C:\Program Files\nodejs\node.exe' }
$argPath = $hookDst.Replace('\', '\\')
$settings = Join-Path $env:USERPROFILE '.claude\settings.json'

Write-Host ""
Write-Host "Next step: merge this into $settings (under a top-level `"hooks`" key):" -ForegroundColor Yellow
Write-Host ""
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
Write-Host ""
if (-not $node) {
  Write-Host "(node was not found on PATH; the snippet uses the default install path - adjust if needed.)" -ForegroundColor DarkYellow
}
Write-Host "Then: restart Claude Code (to load the hook), and in Rainmeter refresh + load ClaudeSessions." -ForegroundColor Yellow
Write-Host "The list fills in as you open/close Claude Code sessions." -ForegroundColor Yellow
