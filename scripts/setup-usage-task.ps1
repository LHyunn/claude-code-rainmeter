# ClaudeUsage - register the 5-minute polling task ("ClaudeUsageWidget").
# Runs poll-hidden.vbs (which runs usage-poll.js hidden) every 5 minutes.
# Per-user task, no admin required.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File setup-usage-task.ps1
# Remove: Unregister-ScheduledTask -TaskName 'ClaudeUsageWidget' -Confirm:$false

$ErrorActionPreference = 'Stop'

$vbs = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins\ClaudeUsage\poll-hidden.vbs'
if (-not (Test-Path -LiteralPath $vbs)) {
  Write-Host "Not found: $vbs" -ForegroundColor Red
  Write-Host "Install the ClaudeUsage skin first (copy it into Documents\Rainmeter\Skins\)." -ForegroundColor Yellow
  exit 1
}

$action  = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $vbs)
$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)).Repetition
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName 'ClaudeUsageWidget' -Action $action -Trigger $trigger -Settings $settings `
  -Description 'Polls claude.ai usage every 5 min for the ClaudeUsage Rainmeter widget.' -Force | Out-Null

Write-Host "[ok] Scheduled task 'ClaudeUsageWidget' registered (runs every 5 minutes)." -ForegroundColor Green
Write-Host "Triggering the first poll now..." -ForegroundColor Yellow
try { Start-ScheduledTask -TaskName 'ClaudeUsageWidget' } catch {}
Write-Host "Done. Make sure Node.js is installed and you are signed in to Claude Code," -ForegroundColor Green
Write-Host "then load the ClaudeUsage skin in Rainmeter. It updates within ~30s of a successful fetch." -ForegroundColor Green
