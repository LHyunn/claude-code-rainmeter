-- ClaudeSessions: ~/.claude/session-log/YYYY-MM.md 파서
-- 한글이 Lua<->Rainmeter 경계(ANSI 변환)에서 깨지므로, 문자열을 bang으로 넘기지 않고
-- UTF-16 LE로 인코딩한 data.inc를 직접 써서 스킨이 @Include로 읽게 한다.
local MAXROWS = 8

-- 로그 위치: Claude Code 기본 위치(~/.claude/session-log)를 사용자별로 자동 해석(이식성).
local function sessionLogDir()
  return (os.getenv('USERPROFILE') or os.getenv('HOME') or '') .. '\\.claude\\session-log'
end

-- UI 문자열. 스킨 변수 Lang=en|ko 로 언어 선택(기본 en).
local STR = {
  en = { noSessions = 'No sessions logged yet', autolog = 'Sessions are logged automatically when they close',
         noContent = '(no content)', today = 'Today', total = 'Total', shown = 'shown',
         tooltip = 'Double-click → resume   ·   Right-click → delete',
         ctxFolder = 'Open log folder', ctxMonth = "Open this month's log" },
  ko = { noSessions = '아직 기록된 세션이 없습니다', autolog = '세션을 닫으면 자동으로 기록됩니다',
         noContent = '(내용 없음)', today = '오늘', total = '전체', shown = '표시 중',
         tooltip = '더블클릭 → resume   ·   우클릭 → 삭제',
         ctxFolder = '로그 폴더 열기', ctxMonth = '이번 달 로그 열기' },
}

-- 기간 표기를 현재 언어로 변환(옛 한글 로그 ↔ 영어 로그 모두 처리; 숫자는 그대로, 단위만 치환).
local function fmtDur(s, lang)
  if lang == 'ko' then return (s:gsub('d', '일'):gsub('h', '시간'):gsub('m', '분')) end
  return (s:gsub('일', 'd'):gsub('시간', 'h'):gsub('분', 'm'))
end

local function readAll(p, mode)
  local f = io.open(p, mode or 'r')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

local function parseEntries(text, list)
  if not text then return end
  local curr
  for line in text:gmatch('[^\r\n]+') do
    if line:sub(1, 3) == '## ' then
      local s, e, cwd = line:match('^## (.-) → (.-) — `(.-)`')
      if s then
        curr = { start = s, cwd = cwd or '', bullets = {}, title = '' }
        local et, dur = e:match('^(.-)%s*%((.-)%)$')
        curr.endt = et or e
        curr.dur = dur or ''
        list[#list + 1] = curr
      end
    elseif curr then
      local id = line:match('^<!%-%- id:(%S+)')
      local t = line:match('^%*%*(.-)%*%*')
      if id then
        curr.id = id
      elseif t then
        curr.title = t
      else
        local b = line:match('^%- (.+)')
        if b then curr.bullets[#curr.bullets + 1] = b end
      end
    end
  end
end

-- ini 변수값으로 들어가므로 Rainmeter가 재해석할 수 있는 문자를 전각으로 치환
local function sanitize(s)
  s = s or ''
  return (s:gsub('#', '＃'):gsub('%[', '［'):gsub('%]', '］'))
end

local function timeline(e, lang)
  local sd, stm = e.start:match('^(%d+%-%d+%-%d+) (%d+:%d+)$')
  local ed, etm = e.endt:match('^(%d+%-%d+%-%d+) (%d+:%d+)$')
  local t
  if sd and ed and sd == ed then
    t = stm .. ' – ' .. etm
  elseif sd and ed then
    t = sd:sub(6):gsub('%-', '/') .. ' ' .. stm .. ' → ' .. ed:sub(6):gsub('%-', '/') .. ' ' .. etm
  elseif etm then
    t = '→ ' .. etm
  else
    t = e.endt
  end
  if e.dur ~= '' then t = t .. '  ·  ' .. fmtDur(e.dur, lang) end
  return t
end

-- UTF-8 문자열 -> UTF-16 LE 바이트열(BOM 포함)
local function utf8to16le(s)
  local out = { '\255\254' }
  local i, n = 1, #s
  while i <= n do
    local c = s:byte(i)
    local cp
    if c < 0x80 then
      cp = c; i = i + 1
    elseif c < 0xE0 then
      cp = (c % 0x20) * 0x40 + (s:byte(i + 1) % 0x40); i = i + 2
    elseif c < 0xF0 then
      cp = (c % 0x10) * 0x1000 + (s:byte(i + 1) % 0x40) * 0x40 + (s:byte(i + 2) % 0x40); i = i + 3
    else
      cp = (c % 0x08) * 0x40000 + (s:byte(i + 1) % 0x40) * 0x1000
        + (s:byte(i + 2) % 0x40) * 0x40 + (s:byte(i + 3) % 0x40); i = i + 4
    end
    if cp < 0x10000 then
      out[#out + 1] = string.char(cp % 256, math.floor(cp / 256))
    else
      cp = cp - 0x10000
      local hi = 0xD800 + math.floor(cp / 0x400)
      local lo = 0xDC00 + (cp % 0x400)
      out[#out + 1] = string.char(hi % 256, math.floor(hi / 256), lo % 256, math.floor(lo / 256))
    end
  end
  return table.concat(out)
end

function Update()
  local ok, err = pcall(RealUpdate)
  if not ok then
    local f = io.open(sessionLogDir() .. '\\lua-error.txt', 'w')
    if f then f:write(tostring(err)); f:close() end
  end
  return 0
end

function RealUpdate()
  local logDir = sessionLogDir()
  local lang = (SKIN:GetVariable('Lang') == 'ko') and 'ko' or 'en'
  local T = STR[lang]
  local incPath = SKIN:GetVariable('CURRENTPATH') .. 'data.inc'
  local y, m = tonumber(os.date('%Y')), tonumber(os.date('%m'))
  local cur = string.format('%04d-%02d', y, m)
  local pm, py = m - 1, y
  if pm == 0 then pm, py = 12, y - 1 end
  local prev = string.format('%04d-%02d', py, pm)

  local list = {}
  parseEntries(readAll(logDir .. '\\' .. prev .. '.md'), list)
  parseEntries(readAll(logDir .. '\\' .. cur .. '.md'), list)

  local today = os.date('%Y-%m-%d')
  local nToday = 0
  for _, e in ipairs(list) do
    if e.endt:match('^(%d+%-%d+%-%d+)') == today then nToday = nToday + 1 end
  end

  -- 스크롤 오프셋 (0 = 최신, 휠로 증감; 범위를 벗어나면 클램프)
  local ofs = tonumber(SKIN:GetVariable('ScrollOfs', '0')) or 0
  local maxOfs = math.max(0, #list - MAXROWS)
  if ofs < 0 then ofs = 0 elseif ofs > maxOfs then ofs = maxOfs end
  SKIN:Bang('!SetVariable', 'ScrollOfs', tostring(ofs))

  local v = { '[Variables]' }
  local shown = 0
  for i = 1, MAXROWS do
    local e = list[#list - ofs - i + 1]
    if e then
      shown = shown + 1
      local title = e.title
      if title == '' or title == '(제목 없음)' or title == '(untitled)' then
        title = e.bullets[1] or T.noContent
      end
      -- 폭 제한·넘침 방지는 ini의 W+ClipString이 픽셀 단위로 처리(글자수 추정보다 정확).
      v[#v + 1] = 'Title' .. i .. '=' .. sanitize(title)
      v[#v + 1] = 'Meta' .. i .. '=' .. sanitize(timeline(e, lang))
      v[#v + 1] = 'Path' .. i .. '=' .. sanitize(e.cwd or '') -- 전체 작업 디렉토리 경로
      v[#v + 1] = 'Id' .. i .. '=' .. (e.id or '')
      v[#v + 1] = 'Cwd' .. i .. '=' .. (e.cwd or '')
      v[#v + 1] = 'Start' .. i .. '=' .. (e.start or '') -- 우클릭 삭제 시 id 중복 구분용(헤더 시작시각)
      v[#v + 1] = 'Row' .. i .. 'Hidden=0'
    else
      if i == 1 then
        shown = 1
        v[#v + 1] = 'Title1=' .. T.noSessions
        v[#v + 1] = 'Meta1=' .. T.autolog
        v[#v + 1] = 'Path1='
        v[#v + 1] = 'Id1='
        v[#v + 1] = 'Cwd1='
        v[#v + 1] = 'Start1='
        v[#v + 1] = 'Row1Hidden=0'
      else
        v[#v + 1] = 'Title' .. i .. '='
        v[#v + 1] = 'Meta' .. i .. '='
        v[#v + 1] = 'Path' .. i .. '='
        v[#v + 1] = 'Id' .. i .. '='
        v[#v + 1] = 'Cwd' .. i .. '='
        v[#v + 1] = 'Start' .. i .. '='
        v[#v + 1] = 'Row' .. i .. 'Hidden=1'
      end
    end
  end
  local stats = T.today .. ' ' .. nToday .. '  ·  ' .. T.total .. ' ' .. #list
  if ofs > 0 then
    stats = '⌃ ' .. (ofs + 1) .. '–' .. math.min(#list, ofs + MAXROWS) .. ' ' .. T.shown .. '  ·  ' .. stats
  end
  v[#v + 1] = 'HeaderStats=' .. stats
  v[#v + 1] = 'ScrollOfs=' .. ofs
  v[#v + 1] = 'MonthFile=' .. cur
  v[#v + 1] = 'LogDir=' .. logDir -- ContextAction(로그 폴더/파일 열기)용 — 자동 해석된 경로
  v[#v + 1] = 'ToolTip=' .. T.tooltip
  v[#v + 1] = 'CtxFolder=' .. T.ctxFolder
  v[#v + 1] = 'CtxMonth=' .. T.ctxMonth
  v[#v + 1] = 'BgH=' .. (94 + shown * 74 + 10) -- 2줄 카드(제목+시간 / 전체경로) 행 간격
  v[#v + 1] = ''

  local content = utf8to16le(table.concat(v, '\r\n'))
  if readAll(incPath, 'rb') ~= content then
    local f = io.open(incPath, 'wb')
    if f then
      f:write(content)
      f:close()
      SKIN:Bang('!Refresh')
    end
  end
  return shown
end
