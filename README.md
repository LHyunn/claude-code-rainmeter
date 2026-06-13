# Claude Code Rainmeter widgets

Two desktop widgets for **[Claude Code](https://claude.com/claude-code)** on Windows, built with [Rainmeter](https://www.rainmeter.net/):

| Widget | What it shows | Interact |
|---|---|---|
| **ClaudeSessions** | Your recent Claude Code sessions (title, time, working directory) | Double‑click to **resume**, right‑click to **delete** |
| **ClaudeUsage** | Your claude.ai subscription usage (5‑hour / 7‑day / Sonnet) with gauges, bars, reset countdowns, and sparklines | Click to open the usage page |

You can install either one independently — they share nothing except this repo.

> 한국어 설명은 맨 아래 [한국어](#한국어) 섹션을 참고하세요.

> [!WARNING]
> **ClaudeUsage uses an _undocumented_ Anthropic endpoint.** It reads the OAuth token that Claude Code stored locally and calls `https://api.anthropic.com/api/oauth/usage` identifying as the CLI. This is **not** an official/supported API: it can break without notice, and automated reuse of the first‑party token **may violate Anthropic's terms**. Use at your own risk. The token is only ever **read** (never modified), only sent over HTTPS to `api.anthropic.com`, and **never stored or logged** by this widget. If in doubt, just use the official page at <https://claude.ai/settings/usage>. **ClaudeSessions has no such concern** — it only reads local log files.

---

## Requirements

| | ClaudeSessions | ClaudeUsage |
|---|:---:|:---:|
| **Windows** + **[Rainmeter](https://www.rainmeter.net/)** 4.x | ✅ | ✅ |
| **[Node.js](https://nodejs.org/)** (LTS) | ✅ (for the log hook) | ✅ (for the poller) |
| **[Claude Code](https://claude.com/claude-code)** | ✅ (`claude` CLI for resume) | ✅ (signed in, for the token) |

---

# ClaudeSessions

A scrollable list of your recent Claude Code sessions. Two pieces:

1. A **session logger** — a Claude Code `SessionStart` / `SessionEnd` hook (`hooks/session-logger.js`) that appends one entry per session to `~/.claude/session-log/YYYY-MM.md`.
2. A **Rainmeter skin** that reads those files and renders them.

### What it looks like

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ✳  Claude Code                                  오늘 7 · 전체 58          │
│ ────────────────────────────────────────────────────────────────────────  │
│  Rebuild entire pipeline from scratch          00:12 – 08:48 · 8시간 36분  │  ← title + time·duration
│  C:\Users\you\Desktop\my-project                                           │  ← full working directory
│                                                                            │
│  Review report and plan next steps      06/11 22:05 → 06/12 00:11 · 2시간  │
│  C:\Users\you\Desktop\another-project                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

All text is hard‑clipped to the panel width, so nothing spills outside the widget regardless of length.

### Features

- **Resume** — double‑click a row → opens a terminal in the session's original directory and runs `claude --resume <id>`.
- **Delete** — right‑click a row → confirmation, then removes that log entry (backup kept in `deleted.md`, reversible). Only the *log entry* is removed; your actual Claude session is untouched and still resumable from a terminal.
- **Scroll** with the mouse wheel; **middle‑click** jumps to the newest.
- **Open the log** by clicking the header.

### How it works

```
Claude Code session starts/ends
        │  SessionStart / SessionEnd hook
        ▼
hooks/session-logger.js  ──appends──►  ~/.claude/session-log/YYYY-MM.md
                                                  │  read every ~60s
                                                  ▼
                                  ClaudeSessions/parser.lua  (Rainmeter Script measure)
                                                  │  writes (UTF-16 LE)
                                                  ▼
                                  data.inc  ──@Include──►  ClaudeSessions.ini  (rendered)
```

`parser.lua` parses the current + previous month's log, writes the row variables to `data.inc` (UTF‑16 LE, to keep Korean text intact), and only refreshes when content changes. Every text meter uses a fixed width + `ClipString`, so long titles/paths clip with `…` instead of overflowing.

### Log entry format

```markdown
## 2026-06-12 09:35 → 2026-06-12 10:32 (57분) — `C:\Users\you\Desktop\my-project`
**Resolve directory trust prompt**  ·  종료: clear · 프롬프트 2개 · `58103caf`
- first prompt text (truncated to ~120 chars)…
<!-- id:58103caf-f032-4672-99ef-4021e0e7413c -->
```

The `<!-- id:... -->` holds the full session id used for resume/delete. The same id can appear in several entries (one per resume), so delete matches on **id + start time** to remove exactly the entry you clicked.

### Install

1. **Skin** — copy the `ClaudeSessions` folder to `%USERPROFILE%\Documents\Rainmeter\Skins\ClaudeSessions`. Keep the folder name (right‑click delete refreshes the config by that name).
2. **Hook** — copy `hooks/session-logger.js` to `%USERPROFILE%\.claude\hooks\session-logger.js`, and add this to `%USERPROFILE%\.claude\settings.json` (merge into an existing `"hooks"` block if present):

   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ { "type": "command", "command": "node", "args": ["C:\\Users\\YOUR_NAME\\.claude\\hooks\\session-logger.js", "start"], "timeout": 15 } ] }
       ],
       "SessionEnd": [
         { "hooks": [ { "type": "command", "command": "node", "args": ["C:\\Users\\YOUR_NAME\\.claude\\hooks\\session-logger.js", "end"], "timeout": 30 } ] }
       ]
     }
   }
   ```

   Replace `YOUR_NAME`; if `node` isn't on `PATH`, use the full `node.exe` path. **Restart Claude Code** so it loads the hook.
3. **Load** the skin in Rainmeter (Refresh all → Manage → ClaudeSessions.ini).

The list fills in as you open/close sessions **after** the hook is installed (it starts empty).

> Or run **`install.ps1`** from the repo root — it copies the skin + hook into place and prints the exact `settings.json` snippet (it does not edit `settings.json` for you).

### Configuration

- `ClaudeSessions/ClaudeSessions.ini` → `[Variables]`: `Width`, `Pad`, and the `Col*` colors.
- `ClaudeSessions/parser.lua` → `MAXROWS` (default `8`, visible rows). If you change it, add/remove matching `[MeterTitle*]`/`[MeterTime*]`/`[MeterPath*]` sections in the `.ini`.

---

# ClaudeUsage

> [!WARNING]
> See the [top‑of‑README warning](#claude-code-rainmeter-widgets) — undocumented endpoint, use at your own risk.

Three usage gauges, updated every 5 minutes:

- **현재 세션 · 5시간 창** — current 5‑hour session window
- **주간 사용량 · 전체 모델** — 7‑day, all models
- **주간 사용량 · Sonnet** — 7‑day, Sonnet

Each shows a big percentage, a progress bar, a "resets in …" countdown, and a sparkline of usage over time. Colors shift from accent → amber (≥75%) → red (≥90%).

### How it works

```
Task Scheduler ("ClaudeUsageWidget", every 5 min)
        │
        ▼
poll-hidden.vbs ──runs hidden──► usage-poll.js
        │  reads ~/.claude/.credentials.json (READ-ONLY)
        │  GET https://api.anthropic.com/api/oauth/usage   ← undocumented
        ▼
data/current.json  +  data/history.jsonl (8-day series)
        │  read every ~30s
        ▼
usage.lua (Rainmeter Script measure) ──writes──► data.inc ──@Include──► ClaudeUsage.ini
```

The poller is read‑only with respect to your credentials, never writes the token anywhere, and writes its output files atomically. `usage.lua` renders only derived numbers/charts.

### Install

1. **Sign in to Claude Code** (so `~/.claude/.credentials.json` exists) and install **Node.js**.
2. **Skin** — copy the `ClaudeUsage` folder to `%USERPROFILE%\Documents\Rainmeter\Skins\ClaudeUsage` (keep the name).
3. **Polling task** — register the 5‑minute task:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup-usage-task.ps1
   ```

   This creates a per‑user scheduled task `ClaudeUsageWidget` that runs `poll-hidden.vbs` every 5 minutes (no admin needed). To remove it later: `Unregister-ScheduledTask -TaskName 'ClaudeUsageWidget' -Confirm:$false`.
4. **Load** the skin in Rainmeter. It populates within ~30s of the first successful fetch.

### Configuration

- `ClaudeUsage/ClaudeUsage.ini` → `[Variables]`: `Width`, `Pad`, colors.
- `ClaudeUsage/usage.lua` → the `METRICS` table (labels and chart time‑windows).
- Poll interval — edit the scheduled task's repetition (default 5 min).

### Troubleshooting

- **Stuck on "대기 중…"** — the poller hasn't produced data. Check Task Scheduler → `ClaudeUsageWidget` ran (Last Result `0`), `data/current.json` exists, and Node is installed (the launcher resolves `node` from `PATH`, falling back to `C:\Program Files\nodejs\node.exe`).
- **"⚠ 토큰 만료"** — the stored token expired; run Claude Code once to refresh it (the widget never modifies the token itself).
- **"⚠ 데이터 지연"** — no fresh data for >11 min; the task probably isn't running.
- **Numbers differ slightly from claude.ai** — timing/rounding; the page is the source of truth.

---

## Repo layout

```
claude-code-rainmeter/
├─ ClaudeSessions/            # skin → Documents\Rainmeter\Skins\ClaudeSessions
│  ├─ ClaudeSessions.ini      #   layout (UTF-16 LE)
│  ├─ parser.lua              #   reads logs → writes data.inc
│  ├─ data.inc                #   generated (placeholder shipped)
│  ├─ resume.ps1              #   double-click → claude --resume
│  └─ delete-session.ps1      #   right-click → delete entry (UTF-8 BOM)
├─ ClaudeUsage/               # skin → Documents\Rainmeter\Skins\ClaudeUsage
│  ├─ ClaudeUsage.ini         #   layout (UTF-16 LE)
│  ├─ usage.lua               #   reads data → writes data.inc
│  ├─ usage-poll.js           #   Node poller (reads token, calls usage API)
│  ├─ poll-hidden.vbs         #   runs the poller hidden
│  └─ data/                   #   current.json + history.jsonl (generated, git-ignored)
├─ hooks/
│  └─ session-logger.js       # ClaudeSessions log hook → ~/.claude/hooks/
├─ scripts/
│  └─ setup-usage-task.ps1    # registers the ClaudeUsage polling task
├─ install.ps1               # installs the ClaudeSessions skin + hook
├─ LICENSE                   # MIT
└─ README.md
```

## Privacy & security

- **Everything is local.** ClaudeSessions reads only `~/.claude/session-log/*.md`. ClaudeUsage reads `~/.claude/.credentials.json` (token, read‑only) and sends it only to `api.anthropic.com` over HTTPS; it stores only usage numbers.
- The session logs contain your **session titles, working‑directory paths, and the first ~120 chars of up to 3 prompts** per session. Treat that folder like shell history — don't sync it somewhere sensitive.
- Deleting a session row archives it to `deleted.md`; it does not delete the resumable Claude session.

## Uninstall

- **ClaudeSessions** — unload + delete the skin; remove the `SessionStart`/`SessionEnd` blocks from `settings.json` and delete `~/.claude/hooks/session-logger.js`; optionally delete `~/.claude/session-log/`.
- **ClaudeUsage** — unload + delete the skin; `Unregister-ScheduledTask -TaskName 'ClaudeUsageWidget' -Confirm:$false`.

## License

MIT — see [LICENSE](LICENSE). Built with [Claude Code](https://claude.com/claude-code).

---

## 한국어

Windows에서 **[Claude Code](https://claude.com/claude-code)**용 Rainmeter 위젯 2종입니다.

- **ClaudeSessions** — 최근 Claude Code 세션 목록(제목·시간·작업 디렉토리). **더블클릭 resume / 우클릭 삭제**.
- **ClaudeUsage** — claude.ai 구독 사용량(5시간/7일/Sonnet) 게이지·막대·리셋 카운트다운·스파크라인.

> ⚠️ **ClaudeUsage 주의:** Claude Code가 저장한 OAuth 토큰을 읽어 **미공개** 엔드포인트(`/api/oauth/usage`)를 CLI인 척 호출합니다. 공식 API가 아니라 **예고 없이 막히거나 약관에 저촉될 수 있습니다.** 자기 책임으로 사용하세요. 토큰은 **읽기만**(수정 안 함), HTTPS로 `api.anthropic.com`에만 전송, **저장·로깅 안 함**. 불안하면 공식 페이지 <https://claude.ai/settings/usage>를 쓰세요. **ClaudeSessions는 로컬 로그만 읽어 이런 문제가 없습니다.**

### 요구 사항
Windows · [Rainmeter](https://www.rainmeter.net/) · [Node.js](https://nodejs.org/)(세션 훅/폴러 실행) · [Claude Code](https://claude.com/claude-code)

### ClaudeSessions 설치
1. `ClaudeSessions` 폴더를 `%USERPROFILE%\Documents\Rainmeter\Skins\ClaudeSessions`에 복사(폴더명 유지).
2. `hooks/session-logger.js`를 `%USERPROFILE%\.claude\hooks\`에 복사하고, `~/.claude/settings.json`에 위 영어 섹션의 `SessionStart`/`SessionEnd` 블록 추가(`YOUR_NAME`을 본인 사용자명으로, `node`가 PATH에 없으면 전체 경로로). **Claude Code 재시작.**
3. Rainmeter에서 새로고침 후 로드. (훅 설치 **이후** 세션부터 기록 — 처음엔 비어 있음.)
4. 또는 레포 루트에서 `install.ps1` 실행(스킨·훅 복사 + 스니펫 출력).

**사용:** 더블클릭=resume, 우클릭=삭제(확인창, `deleted.md`에 백업), 휠=스크롤, 휠클릭=맨 위, 헤더 클릭=로그 열기.

### ClaudeUsage 설치
1. Claude Code에 로그인(토큰 존재) + Node.js 설치.
2. `ClaudeUsage` 폴더를 `Skins\ClaudeUsage`에 복사.
3. 5분 폴링 작업 등록: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup-usage-task.ps1` (관리자 불필요). 제거: `Unregister-ScheduledTask -TaskName 'ClaudeUsageWidget' -Confirm:$false`.
4. Rainmeter에서 로드. 첫 수집 후 ~30초 내 표시.

**문제 해결:** "대기 중…"이 계속 → 작업 실행/`current.json`/Node 확인. "토큰 만료" → Claude Code 한 번 실행해 토큰 갱신. "데이터 지연" → 작업 미실행.

### 설정
- 색상/폭: 각 위젯 `.ini`의 `[Variables]`. 표시 개수: ClaudeSessions `parser.lua`의 `MAXROWS`(기본 8). 폴링 주기: ClaudeUsage 예약 작업.
- UI 언어 변경 시 `parser.lua`/`session-logger.js`/`usage.lua`의 한글 문자열 수정. 인코딩 유지(.ini·data.inc = UTF‑16 LE, delete-session.ps1 = UTF‑8 BOM).

### 개인정보
전부 **로컬**. 세션 로그엔 제목·작업 경로·프롬프트 앞 ~120자가 담깁니다. ClaudeUsage는 토큰을 읽기 전용으로만 사용하고 사용량 숫자만 저장합니다.

MIT 라이선스 · [Claude Code](https://claude.com/claude-code)로 제작.
