-- ClaudeUsage: data/current.json + data/history.jsonl → data.inc (게이지·차트·카운트다운).
-- 한글 인코딩 경계 회피를 위해 data.inc를 UTF-16 LE로 직접 기록(ClaudeSessions와 동일 패턴).

local CHART_W = 716
local CHART_H = 86
local BAR_W = 240
-- 메트릭: {키, 라벨, 차트 시간창(ms)}
local METRICS = {
  { id = '5', hk = 'h5', label = '현재 세션  ·  5시간 창', win = 6 * 3600 * 1000 },
  { id = '7', hk = 'd7', label = '주간 사용량  ·  전체 모델', win = 7 * 86400 * 1000 },
  { id = 'S', hk = 's7', label = '주간 사용량  ·  Sonnet', win = 7 * 86400 * 1000 },
}

local function readAll(p, mode)
  local f = io.open(p, mode or 'r'); if not f then return nil end
  local s = f:read('*a'); f:close(); return s
end

-- UTF-8 → UTF-16 LE(BOM 포함)
local function u16(s)
  local out = { '\255\254' }
  local i, n = 1, #s
  while i <= n do
    local c = s:byte(i); local cp, sz
    if c < 0x80 then cp, sz = c, 1
    elseif c < 0xE0 then cp, sz = (c % 0x20) * 0x40 + (s:byte(i + 1) % 0x40), 2
    elseif c < 0xF0 then cp, sz = (c % 0x10) * 0x1000 + (s:byte(i + 1) % 0x40) * 0x40 + (s:byte(i + 2) % 0x40), 3
    else cp, sz = (c % 0x08) * 0x40000 + (s:byte(i + 1) % 0x40) * 0x1000 + (s:byte(i + 2) % 0x40) * 0x40 + (s:byte(i + 3) % 0x40), 4 end
    if cp < 0x10000 then out[#out + 1] = string.char(cp % 256, math.floor(cp / 256))
    else cp = cp - 0x10000; local hi = 0xD800 + math.floor(cp / 0x400); local lo = 0xDC00 + (cp % 0x400)
      out[#out + 1] = string.char(hi % 256, math.floor(hi / 256), lo % 256, math.floor(lo / 256)) end
    i = i + sz
  end
  return table.concat(out)
end

-- current.json 파싱: 키의 객체를 통째로(%b{}) 잡은 뒤 내부에서 u/reset을 개별 추출 → 키 순서·여백에 둔감.
-- 스키마(키 이름)는 usage-poll.js와 공유하는 계약.
local function metric(text, key)
  local obj = text:match('"' .. key .. '":(%b{})')
  if not obj then return nil, nil end
  return tonumber(obj:match('"u":([%w%.%-]+)')), tonumber(obj:match('"reset":([%w%.%-]+)')) -- null이면 nil
end

local function fmtClock(ms)
  if not ms then return '--:--' end
  return os.date('%H:%M', math.floor(ms / 1000))
end

local function countdown(ms, now)
  if not ms then return '' end
  local s = math.floor((ms - now) / 1000)
  if s <= 0 then return '리셋 중…' end
  local d = math.floor(s / 86400); local h = math.floor((s % 86400) / 3600); local m = math.floor((s % 3600) / 60)
  if d > 0 then return string.format('%d일 %d시간 후 리셋', d, h) end
  if h > 0 then return string.format('%d시간 %d분 후 리셋', h, m) end
  return string.format('%d분 후 리셋', m)
end

local function levelRGB(u)
  if u == nil then return '140,140,150' end
  if u >= 90 then return '226,104,104' end   -- red
  if u >= 75 then return '224,176,92' end    -- amber
  return '217,119,87'                        -- accent
end

local function clampU(u) if u < 0 then return 0 elseif u > 100 then return 100 end return u end

-- 시계열 → (라인 path, 영역 path, 마지막점 x,y, 그릴 수 있는지)
local function chartPaths(hist, hk, win, now)
  local pts = {}
  local tmin, tmax
  for _, r in ipairs(hist) do
    local v = r[hk]
    if v ~= nil and r.t >= now - win then
      local x = CHART_W * (1 - (now - r.t) / win)
      local y = CHART_H * (1 - clampU(v) / 100)
      pts[#pts + 1] = { x, y }
      if not tmin then tmin = r.t end
      tmax = r.t
    end
  end
  -- 포인트가 2개 미만이거나 실제 수집 구간이 30분 미만이면 '수집 중'
  -- (시간창 대비 %가 아닌 절대 시간 기준 → 주간 차트도 30분이면 그려짐)
  if #pts < 2 or (tmax - tmin) < 30 * 60 * 1000 then
    return nil, nil, (pts[#pts] and pts[#pts][1] or nil), (pts[#pts] and pts[#pts][2] or nil), false
  end
  local seg = { string.format('%.1f,%.1f', pts[1][1], pts[1][2]) }
  for i = 2, #pts do seg[#seg + 1] = string.format('LineTo %.1f,%.1f', pts[i][1], pts[i][2]) end
  local line = table.concat(seg, ' | ')
  local area = line .. string.format(' | LineTo %.1f,%.1f | LineTo %.1f,%.1f | ClosePath 1',
    pts[#pts][1], CHART_H, pts[1][1], CHART_H)
  return line, area, pts[#pts][1], pts[#pts][2], true
end

function Update()
  local ok, err = pcall(RealUpdate)
  if not ok then local f = io.open(SKIN:GetVariable('CURRENTPATH') .. 'lua-error.txt', 'w'); if f then f:write(tostring(err)); f:close() end end
  return 0
end

function RealUpdate()
  local base = SKIN:GetVariable('CURRENTPATH')
  local cur = readAll(base .. 'data\\current.json') or ''
  local realNow = os.time() * 1000

  local status = cur:match('"status":"(%a+)"') or 'none'
  local fetched = tonumber(cur:match('"fetched_at":(%d+)'))
  local checked = tonumber(cur:match('"checked_at":(%d+)')) or fetched
  -- 차트·카운트다운은 '마지막 폴링 시각' 기준으로 계산. 폴링(5분) 사이의 30초 틱에서는 출력이 변하지 않아
  -- data.inc가 매 틱 바뀌어 전체 !Refresh가 반복되던 문제를 없앤다(스테일 판정만 실시간 realNow 사용).
  local now = checked or fetched or realNow

  -- 히스토리 로드
  local hist = {}
  local ht = readAll(base .. 'data\\history.jsonl')
  if ht then
    for line in ht:gmatch('[^\r\n]+') do
      -- 키 순서·여백에 둔감하게 개별 추출(usage-poll.js의 history row 키 이름과 공유하는 계약).
      local t = tonumber(line:match('"t":(%-?%d+)'))
      if t then hist[#hist + 1] = {
        t = t,
        h5 = tonumber(line:match('"h5":([%w%.%-]+)')),
        d7 = tonumber(line:match('"d7":([%w%.%-]+)')),
        s7 = tonumber(line:match('"s7":([%w%.%-]+)')),
      } end
    end
  end

  local v = { '[Variables]' }
  local function set(k, val) v[#v + 1] = k .. '=' .. val end

  for _, M in ipairs(METRICS) do
    local u, reset = metric(cur, M.id == '5' and 'five_hour' or M.id == '7' and 'seven_day' or 'sonnet')
    local id = M.id
    local rgb = levelRGB(u)
    set('Label' .. id, M.label)
    set('Pct' .. id, u == nil and '—' or (string.format('%d', math.floor(u + 0.5)) .. '%'))
    set('Color' .. id, rgb .. ',255')
    set('ColorA' .. id, rgb .. ',40')
    set('BarW' .. id, tostring(math.max(1, math.floor(BAR_W * clampU(u or 0) / 100))))
    set('Reset' .. id, reset and countdown(reset, now) or '')
    local line, area, dx, dy, drawable = chartPaths(hist, M.hk, M.win, now)
    if drawable then
      set('Line' .. id, line)
      set('Area' .. id, area)
      set('Dot' .. id .. 'X', string.format('%.1f', dx))
      set('Dot' .. id .. 'Y', string.format('%.1f', dy))
      set('ChartNote' .. id, '')
    else
      -- 빈 상태: 차트 프레임 안 베이스라인으로 축약. 화면 밖 -9999 좌표는 DynamicWindowSize 경계를
      -- 거대하게 부풀려(보이지 않는 클릭 영역) 문제였으므로 (0,86) 안쪽으로 둔다.
      set('Line' .. id, '0,86 | LineTo 0,86')
      set('Area' .. id, '0,86 | LineTo 0,86 | ClosePath 1')
      set('Dot' .. id .. 'X', '0')
      set('Dot' .. id .. 'Y', '86')
      set('ChartNote' .. id, '데이터 수집 중…')
    end
  end

  -- 헤더 상태
  local note = ''
  if status == 'token_expired' then note = '⚠ 토큰 만료 — Claude Code 실행 시 자동 갱신'
  elseif status ~= 'ok' and status ~= 'none' then note = '⚠ 가져오기 실패 (' .. status .. ')'
  elseif status == 'none' then note = '대기 중…' end
  local upd = fetched and ('갱신 ' .. fmtClock(fetched)) or ''
  -- 데이터가 오래되면(>11분) 흐릿 표시용 플래그
  if checked and (realNow - checked) > 11 * 60 * 1000 and note == '' then note = '⚠ 데이터 지연' end
  set('HeaderNote', (note ~= '' and (note .. '   ') or '') .. upd)

  local content = u16(table.concat(v, '\r\n') .. '\r\n')
  local incPath = base .. 'data.inc'
  if readAll(incPath, 'rb') ~= content then
    local f = io.open(incPath, 'wb')
    if f then f:write(content); f:close(); SKIN:Bang('!Refresh') end
  end
  return 0
end
