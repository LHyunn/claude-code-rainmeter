# Claude Sessions — Rainmeter widget

A desktop widget that shows your recent **[Claude Code](https://claude.com/claude-code)** sessions on your Windows desktop, and lets you **resume** any of them with a double‑click or **delete** them with a right‑click.

It is two pieces working together:

1. A small **session logger** — a Claude Code `SessionStart` / `SessionEnd` hook that appends one entry per session to a monthly Markdown file under `~/.claude/session-log/`.
2. A **Rainmeter skin** that reads those files and renders them as a scrollable, interactive list.

> 한국어 설명은 맨 아래 [한국어](#한국어) 섹션을 참고하세요.

---

## What it looks like

Each row is a session, newest first:

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ✳  Claude Code                                  오늘 7 · 전체 58          │
│ ────────────────────────────────────────────────────────────────────────  │
│  Rebuild entire pipeline from scratch          00:12 – 08:48 · 8시간 36분  │  ← title + time·duration
│  C:\Users\you\Desktop\my-project                                           │  ← full working directory
│                                                                            │
│  Review report and plan next steps      06/11 22:05 → 06/12 00:11 · 2시간  │
│  C:\Users\you\Desktop\another-project                                      │
│  …                                                                         │
└──────────────────────────────────────────────────────────────────────────┘
```

- **Line 1** — session title (AI‑generated or your custom title) on the left, time range and duration on the right.
- **Line 2** — the full working‑directory path the session ran in.

All text is hard‑clipped to the panel width, so nothing ever spills outside the widget regardless of length.

---

## Features

- **Resume a session** — double‑click a row. Opens a terminal in the session's original directory and runs `claude --resume <id>`.
- **Delete a session entry** — right‑click a row. Shows a confirmation, then removes that entry from the log (a backup is kept in `deleted.md`, so it is reversible). This only removes the *log entry* — your actual Claude session data is untouched, so `claude --resume` from a terminal still works.
- **Scroll** — mouse wheel scrolls through older sessions; middle‑click jumps back to the newest.
- **Open the log** — click the header (or use the right‑click menu) to open the current month's Markdown log / the log folder.
- **Korean UI** by default (the widget and logger emit Korean labels). See [Translating the UI](#translating-the-ui) to change it.
- **Portable** — paths resolve automatically from `%USERPROFILE%`; no per‑machine path editing required for the common case.

---

## How it works

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
                                  ClaudeSessions/data.inc  ──@Include──►  ClaudeSessions.ini  (rendered)
```

- **`session-logger.js`** runs on every session start (records the start time) and end (reads the transcript, extracts the title + first few prompts + duration, and appends a Markdown entry). Sessions that are opened and closed with no prompts are skipped.
- **`parser.lua`** is a Rainmeter Script measure. It parses the current and previous month's log, builds the row variables, and writes them to `data.inc` encoded as UTF‑16 LE (this avoids Korean text corruption at the Lua↔Rainmeter boundary). It only rewrites `data.inc` when the content actually changes, then refreshes the skin.
- **`ClaudeSessions.ini`** `@Include`s `data.inc` and renders the meters. Every text meter uses a fixed width + `ClipString`, so long titles/paths are clipped (with `…`) instead of overflowing.

### Log entry format

Each entry in `YYYY-MM.md` looks like:

```markdown
## 2026-06-12 09:35 → 2026-06-12 10:32 (57분) — `C:\Users\you\Desktop\my-project`
**Resolve directory trust prompt**  ·  종료: clear · 프롬프트 2개 · `58103caf`
- first prompt text (truncated to ~120 chars)…
- second prompt text…
<!-- id:58103caf-f032-4672-99ef-4021e0e7413c -->
```

The `<!-- id:... -->` comment holds the full session id used for resume/delete. The same id can legitimately appear in multiple entries (one per resume), so delete matches on **id + start time** to remove exactly the entry you clicked.

---

## Requirements

| Requirement | Why | Notes |
|---|---|---|
| **Windows** | Rainmeter is Windows‑only | — |
| **[Rainmeter](https://www.rainmeter.net/)** | renders the widget | 4.x |
| **[Node.js](https://nodejs.org/)** | runs the session‑logger hook | any recent LTS; the widget itself needs no Node |
| **[Claude Code](https://claude.com/claude-code)** | the thing being logged | the `claude` CLI is needed for *resume* |

---

## Installation

### 1. Install the skin

Copy the **`ClaudeSessions`** folder into your Rainmeter skins folder:

```
%USERPROFILE%\Documents\Rainmeter\Skins\ClaudeSessions
```

> Keep the folder name **`ClaudeSessions`** — the right‑click delete refreshes the Rainmeter config by that exact name.

### 2. Install the session‑logger hook

Copy `hooks/session-logger.js` to:

```
%USERPROFILE%\.claude\hooks\session-logger.js
```

Then add the hook to `%USERPROFILE%\.claude\settings.json`. If the file already has a `"hooks"` block, merge these two arrays into it:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node",
            "args": ["C:\\Users\\YOUR_NAME\\.claude\\hooks\\session-logger.js", "start"],
            "timeout": 15
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node",
            "args": ["C:\\Users\\YOUR_NAME\\.claude\\hooks\\session-logger.js", "end"],
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

- Replace `YOUR_NAME` with your Windows username (or use the absolute path to the file).
- If `node` is not on your `PATH`, replace `"node"` with the full path, e.g. `"C:\\Program Files\\nodejs\\node.exe"`.

> Or run `install.ps1` (see [Quick install](#quick-install)) to copy the files and print the exact snippet for you.

### 3. Load the widget

In Rainmeter, refresh (right‑click the tray icon → **Refresh all**) and load **ClaudeSessions / ClaudeSessions.ini** from *Manage*.

### 4. Start using Claude Code

The widget logs sessions **from the moment the hook is installed onward** — it starts empty and fills in as you open and close Claude Code sessions. (Sessions that ran before the hook existed are not shown.)

### Quick install

From the repo root in PowerShell:

```powershell
.\install.ps1
```

It copies the skin and the hook into place and prints the `settings.json` snippet to paste. It does **not** edit `settings.json` automatically (to avoid corrupting your config).

---

## Usage

| Action | Result |
|---|---|
| **Double‑click** a row | Resume that session (`claude --resume`) in its original directory |
| **Right‑click** a row | Delete that log entry (with confirmation; backup kept) |
| **Mouse wheel** | Scroll through older sessions |
| **Middle‑click** | Jump back to the newest session |
| **Click the header** | Open the current month's log file |

---

## Configuration

Everything is plain text — edit and refresh the skin.

**`ClaudeSessions/ClaudeSessions.ini`** → `[Variables]`:

| Variable | Default | Meaning |
|---|---|---|
| `Width` | `1080` | widget width (px) |
| `Pad` | `24` | inner padding |
| `ColBg`, `ColStroke`, `ColAccent`, `ColTitle`, `ColMeta`, `ColDivider` | — | colors (`R,G,B,A`) |

**`ClaudeSessions/parser.lua`**:

| Setting | Default | Meaning |
|---|---|---|
| `MAXROWS` | `8` | how many sessions are visible at once |

Row layout (title/time/path widths, fonts) lives in the `[MeterTitle*]` / `[MeterTime*]` / `[MeterPath*]` sections of the `.ini`. If you change `MAXROWS`, add or remove matching row sections.

### Translating the UI

The Korean strings live in two places:

- **`parser.lua`** — labels like `아직 기록된 세션이 없습니다`, `오늘`, `전체`, and the time/duration formatting in `timeline()`.
- **`session-logger.js`** — duration text (`시간` / `분`) and the entry header (`종료:`, `프롬프트`, `개`).

Replace those literals with your language. Keep `parser.lua` / `data.inc` as UTF‑16 LE and `delete-session.ps1` as UTF‑8 **with BOM** so non‑ASCII text isn't corrupted.

---

## Troubleshooting

**The widget is empty / says "아직 기록된 세션이 없습니다".**
- It only shows sessions logged after the hook was installed — open and close a Claude Code session, then wait up to ~60s (or refresh the skin).
- Check that `~/.claude/session-log/YYYY-MM.md` exists and is growing. If not, the hook isn't firing: verify `settings.json`, that `node` resolves, and **restart Claude Code** so it reloads hooks.
- Look for `~/.claude/session-log/lua-error.txt` (parser error) or `delete-error.txt` (delete error).

**The widget doesn't update.**
- The parser runs every ~60s. Refresh the skin to force an update.

**Double‑click does nothing / resume fails.**
- `claude` must be on your `PATH`, or installed at `%USERPROFILE%\.local\bin\claude.exe`. Otherwise edit `resume.ps1`.
- A session can only be resumed if its original working directory still exists.

**Right‑click delete does nothing.**
- Rainmeter must be installed at `C:\Program Files\Rainmeter\Rainmeter.exe` for the auto‑refresh after delete. For other locations, edit the `$rm` path in `delete-session.ps1`. (The deletion itself still works; only the immediate refresh is affected.)

**Korean text shows as boxes/garbage.**
- File encodings matter: `ClaudeSessions.ini` and `data.inc` must be UTF‑16 LE; `delete-session.ps1` must be UTF‑8 with BOM. Re‑download the files if your editor re‑saved them in a different encoding.

---

## Privacy & security

- Everything is **local**. The widget reads only `~/.claude/session-log/*.md`; nothing is sent anywhere.
- Those log files contain your **session titles, working‑directory paths, and the first ~120 characters of up to 3 prompts per session**. Treat the folder as you would your shell history. Don't commit it or sync it to shared/cloud locations if that's sensitive.
- Deleting a row removes its log entry (archived to `deleted.md`); it does **not** delete the underlying Claude session, which remains resumable from a terminal.

---

## Uninstall

1. In Rainmeter, unload the skin and delete `Documents\Rainmeter\Skins\ClaudeSessions`.
2. Remove the `SessionStart` / `SessionEnd` blocks you added to `~/.claude/settings.json`, and delete `~/.claude/hooks/session-logger.js`.
3. Optionally delete `~/.claude/session-log/` (your logged history).

---

## Repo layout

```
claude-sessions-rainmeter/
├─ ClaudeSessions/            # the Rainmeter skin (install into Skins/)
│  ├─ ClaudeSessions.ini      #   layout & rendering (UTF-16 LE)
│  ├─ parser.lua              #   reads logs → writes data.inc
│  ├─ data.inc                #   generated variables (placeholder shipped)
│  ├─ resume.ps1              #   double-click → claude --resume
│  └─ delete-session.ps1      #   right-click → delete entry (UTF-8 BOM)
├─ hooks/
│  └─ session-logger.js       # Claude Code SessionStart/End hook (install into ~/.claude/hooks/)
├─ install.ps1               # optional installer helper
├─ LICENSE
└─ README.md
```

---

## License

MIT — see [LICENSE](LICENSE).

Built with [Claude Code](https://claude.com/claude-code).

---

## 한국어

Windows 바탕화면에 최근 **[Claude Code](https://claude.com/claude-code)** 세션 목록을 보여주고, **더블클릭으로 이어하기(resume)**, **우클릭으로 삭제**할 수 있는 Rainmeter 위젯입니다.

두 부분으로 구성됩니다:
1. **세션 로거** — Claude Code의 `SessionStart`/`SessionEnd` 훅으로, 세션마다 한 줄씩 `~/.claude/session-log/YYYY-MM.md`에 기록합니다.
2. **Rainmeter 스킨** — 그 로그를 읽어 스크롤 가능한 인터랙티브 목록으로 그립니다.

### 동작 구조

```
Claude Code 세션 시작/종료
        │  SessionStart / SessionEnd 훅
        ▼
hooks/session-logger.js  ──기록──►  ~/.claude/session-log/YYYY-MM.md
                                            │  약 60초마다 읽음
                                            ▼
                            ClaudeSessions/parser.lua (Rainmeter Script measure)
                                            │  UTF-16 LE로 기록
                                            ▼
                            data.inc  ──@Include──►  ClaudeSessions.ini (렌더링)
```

각 행: **1줄** 제목 + 시간·활동시간, **2줄** 전체 작업 디렉토리 경로. 모든 텍스트는 패널 폭에 맞춰 잘려서(`…`) 위젯 밖으로 넘치지 않습니다.

### 요구 사항
- Windows · [Rainmeter](https://www.rainmeter.net/) · [Node.js](https://nodejs.org/)(훅 실행용) · [Claude Code](https://claude.com/claude-code)(이어하기엔 `claude` CLI 필요)

### 설치
1. **스킨**: `ClaudeSessions` 폴더를 `%USERPROFILE%\Documents\Rainmeter\Skins\ClaudeSessions`에 복사. (폴더명 `ClaudeSessions` 유지 — 우클릭 삭제가 이 이름으로 새로고침합니다.)
2. **훅**: `hooks/session-logger.js`를 `%USERPROFILE%\.claude\hooks\`에 복사하고, `~/.claude/settings.json`에 위 영어 섹션의 `SessionStart`/`SessionEnd` 블록을 추가. `YOUR_NAME`을 본인 사용자명으로, `node`가 PATH에 없으면 `node.exe` 전체 경로로 바꾸세요. (또는 `install.ps1` 실행 → 파일 복사 + 붙여넣을 스니펫 출력.)
3. Rainmeter에서 새로고침 후 스킨 로드.
4. 이후 Claude Code를 쓰면 세션이 기록되어 목록이 채워집니다. (훅 설치 **이후** 세션만 표시됩니다 — 처음엔 비어 있습니다.)

### 사용
- **더블클릭** → 그 세션을 원래 폴더에서 `claude --resume`
- **우클릭** → 그 로그 항목 삭제(확인창, `deleted.md`에 백업 — 복구 가능). 로그 항목만 지우며 실제 Claude 세션은 남아 터미널에서 resume 가능.
- **휠** 스크롤 · **휠클릭** 맨 위로 · **헤더 클릭** 이번 달 로그 열기

### 설정
- 색상/폭: `ClaudeSessions.ini`의 `[Variables]`. 표시 개수: `parser.lua`의 `MAXROWS`(기본 8). `MAXROWS`를 바꾸면 `.ini`의 행 섹션도 같이 추가/삭제하세요.
- UI 언어 변경: `parser.lua`와 `session-logger.js`의 한글 문자열을 수정. 인코딩 유지(.ini/data.inc는 UTF‑16 LE, delete-session.ps1은 UTF‑8 BOM).

### 문제 해결
- **빈 목록**: 훅 설치 후 세션을 열고 닫아야 채워집니다(최대 ~60초). `~/.claude/session-log/`에 `.md`가 생기는지 확인. 안 생기면 훅 미작동 → `settings.json`·`node` 확인 후 **Claude Code 재시작**. 오류는 `lua-error.txt`/`delete-error.txt` 확인.
- **resume 실패**: `claude`가 PATH에 있거나 `%USERPROFILE%\.local\bin\claude.exe`에 있어야 함. 원래 작업 폴더가 사라졌으면 불가.
- **한글 깨짐**: 파일 인코딩 확인(.ini·data.inc = UTF‑16 LE, delete-session.ps1 = UTF‑8 BOM).

### 개인정보
- 전부 **로컬**입니다. 로그(.md)에는 세션 제목·작업 경로·세션당 최대 3개 프롬프트의 앞 ~120자가 담깁니다. 셸 히스토리처럼 취급하세요(민감하면 공유/클라우드 동기화 주의).

MIT 라이선스. [Claude Code](https://claude.com/claude-code)로 제작.
