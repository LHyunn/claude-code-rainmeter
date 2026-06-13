# ClaudeSessions 위젯 더블클릭 → 해당 세션 resume.
# 인자: <원래 작업 디렉토리> <세션 전체 ID>. claude --resume 는 원래 cwd에서만 동작.
param([string]$Cwd, [string]$Id)

# claude 실행 파일: PATH 우선, 없으면 기본 설치 경로(~/.local/bin)
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { $claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe' }

if (-not $Id) { exit }
if (-not (Test-Path -LiteralPath $Cwd)) {
  Write-Host ("Original working directory not found:`n  {0}" -f $Cwd) -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit
}

Set-Location -LiteralPath $Cwd
$Host.UI.RawUI.WindowTitle = "claude --resume $Id"
& $claude --resume $Id

if ($LASTEXITCODE -ne 0) {
  Write-Host "`n[resume failed - see message above]" -ForegroundColor Red
  Read-Host "Press Enter to close"
}
