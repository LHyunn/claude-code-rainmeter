# ClaudeSessions 위젯: 행 우클릭 → 해당 세션 로그 항목 삭제.
# 인자: -Id <세션 전체 ID> [-Start "YYYY-MM-DD HH:MM"] [-LogDir <경로>] [-Force]
# 같은 id가 여러 블록으로 존재할 수 있어(같은 세션 다회 resume) -Start(헤더 시작시각)로 정확히 구분.
# 표시 목록(YYYY-MM.md)에서 그 블록만 제거하고 deleted.md 로 백업(복구 가능).
# 실제 Claude 세션 데이터는 건드리지 않음 → 터미널 claude --resume 은 그대로 가능.
param(
  [Parameter(Mandatory = $true)][string]$Id,
  [string]$Start = '',
  [string]$LogDir = (Join-Path $env:USERPROFILE '.claude\session-log'),
  [switch]$Force
)
$ErrorActionPreference = 'Stop'

function Test-IsTarget($block, $marker, $start) {
  if (-not $block.Contains($marker)) { return $false }
  if ([string]::IsNullOrEmpty($start)) { return $true }
  $fl = (($block -split "`n")[0]).TrimEnd("`r")
  return $fl.StartsWith("## $start ")
}

try {
  $Id = $Id.Trim(); $Start = $Start.Trim()
  if ([string]::IsNullOrWhiteSpace($Id)) { return }
  $marker = "<!-- id:$Id -->"

  $files = Get-ChildItem -LiteralPath $LogDir -Filter '*.md' -File |
    Where-Object { $_.Name -match '^\d{4}-\d{2}\.md$' }

  $target = $null; $removed = $null; $kept = $null
  foreach ($f in $files) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    if (-not $t.Contains($marker)) { continue }
    $parts = [regex]::Split($t, '(?m)(?=^## )')
    $rem = $null
    $kp = New-Object System.Collections.Generic.List[string]
    foreach ($p in $parts) {
      if (-not $rem -and (Test-IsTarget $p $marker $Start)) { $rem = $p } else { $kp.Add($p) }
    }
    if ($rem) { $target = $f; $removed = $rem; $kept = $kp; break }
  }
  if (-not $removed) { return }

  if (-not $Force) {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $hdr = (($removed -split "`n")[0]).TrimEnd("`r")
    $tm = [regex]::Match($removed, '(?m)^\*\*(.*?)\*\*')
    $title = if ($tm.Success) { $tm.Groups[1].Value } else { '(제목 없음)' }
    $msg = "이 세션을 목록에서 삭제할까요?`n`n" + $title + "`n" + $hdr + "`n`n복구본은 deleted.md 에 보관됩니다."
    $ans = [System.Windows.Forms.MessageBox]::Show($msg, 'ClaudeSessions — 세션 삭제',
      [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
  }

  $enc = New-Object System.Text.UTF8Encoding($false)   # BOM 없이(파서가 첫 줄 BOM에 민감)
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $archive = Join-Path $LogDir 'deleted.md'
  [System.IO.File]::AppendAllText($archive,
    "<!-- deleted $stamp from $($target.Name) -->`r`n" + $removed.TrimEnd() + "`r`n`r`n", $enc)

  $newText = [string]::Join('', $kept)
  $tmp = $target.FullName + '.tmp'
  $bak = $target.FullName + '.bak'
  [System.IO.File]::WriteAllText($tmp, $newText, $enc)
  [System.IO.File]::Replace($tmp, $target.FullName, $bak)   # 원자적 교체(백업 경유)
  [System.IO.File]::Delete($bak)

  $rm = 'C:\Program Files\Rainmeter\Rainmeter.exe'
  if (Test-Path -LiteralPath $rm) { & $rm '!Refresh' 'ClaudeSessions' }
}
catch {
  try {
    [System.IO.File]::WriteAllText((Join-Path $LogDir 'delete-error.txt'),
      $_.ToString(), (New-Object System.Text.UTF8Encoding($false)))
  } catch { }
}