// ClaudeUsage 폴러 — claude.ai 구독 사용량(/api/oauth/usage)을 5분마다 수집.
// Claude Code가 저장한 OAuth accessToken을 '읽기 전용'으로만 사용(.credentials.json 미수정).
// 출력: data/current.json (현재 스냅샷), data/history.jsonl (시계열, 8일 보관).
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');

const DATA = path.join(__dirname, 'data');
const CRED = path.join(os.homedir(), '.claude', '.credentials.json');
const HIST = path.join(DATA, 'history.jsonl');
const CUR = path.join(DATA, 'current.json');

// temp 파일에 쓰고 rename → 같은 볼륨에서 원자적. 소비자(usage.lua)가 30초마다 읽으므로 찢긴 파일 방지.
function writeFileAtomic(p, data) {
  const tmp = p + '.tmp';
  fs.writeFileSync(tmp, data);
  fs.renameSync(tmp, p);
}

function writeCurrent(obj) {
  try { writeFileAtomic(CUR, JSON.stringify(obj)); } catch (e) {}
}

function loadCurrent() {
  try { return JSON.parse(fs.readFileSync(CUR, 'utf8')); } catch (e) { return {}; }
}

function main() {
  fs.mkdirSync(DATA, { recursive: true });
  let tok, exp;
  try {
    const c = JSON.parse(fs.readFileSync(CRED, 'utf8')).claudeAiOauth;
    tok = c.accessToken; exp = c.expiresAt;
  } catch (e) {
    const cur = loadCurrent(); cur.ok = false; cur.status = 'no_credentials'; writeCurrent(cur); return;
  }
  if (exp && exp <= Date.now()) {
    // 토큰 만료 — .credentials.json은 절대 건드리지 않음. Claude Code 실행 시 자동 갱신됨.
    const cur = loadCurrent(); cur.ok = false; cur.status = 'token_expired'; cur.checked_at = Date.now(); writeCurrent(cur); return;
  }

  const req = https.request('https://api.anthropic.com/api/oauth/usage', {
    method: 'GET',
    headers: {
      'Authorization': 'Bearer ' + tok,
      'anthropic-beta': 'oauth-2025-04-20',
      'anthropic-version': '2023-06-01',
      'User-Agent': 'claude-cli',
      'Accept': 'application/json',
    },
  }, r => {
    let d = '';
    r.on('data', c => d += c);
    r.on('end', () => {
      if (r.statusCode !== 200) {
        const cur = loadCurrent(); cur.ok = false; cur.status = 'http_' + r.statusCode; cur.checked_at = Date.now(); writeCurrent(cur); return;
      }
      let j;
      try { j = JSON.parse(d); } catch (e) {
        const cur = loadCurrent(); cur.ok = false; cur.status = 'bad_json'; cur.checked_at = Date.now(); writeCurrent(cur); return;
      }
      const num = x => (x && typeof x.utilization === 'number') ? x.utilization : null;
      const rms = x => (x && x.resets_at) ? Date.parse(x.resets_at) : null; // epoch ms
      const now = Date.now();
      const cur = {
        ok: true, status: 'ok', fetched_at: now, checked_at: now,
        five_hour: { u: num(j.five_hour), reset: rms(j.five_hour) },
        seven_day: { u: num(j.seven_day), reset: rms(j.seven_day) },
        sonnet: { u: num(j.seven_day_sonnet), reset: rms(j.seven_day_sonnet) },
        opus: { u: num(j.seven_day_opus), reset: rms(j.seven_day_opus) },
      };
      writeCurrent(cur);

      // 시계열 누적 (값이 모두 null이면 기록 안 함)
      if (cur.five_hour.u !== null || cur.seven_day.u !== null || cur.sonnet.u !== null) {
        // 키 이름/형식은 usage.lua가 문자열 패턴으로 읽음(키 순서엔 둔감하지만 키 이름은 공유 계약).
        const row = { t: now, h5: cur.five_hour.u, d7: cur.seven_day.u, s7: cur.sonnet.u };
        let lines = [];
        try { lines = fs.readFileSync(HIST, 'utf8').split('\n').filter(Boolean); } catch (e) {}
        lines.push(JSON.stringify(row));
        // 8일 초과 데이터 정리
        const cutoff = now - 8 * 864e5;
        lines = lines.filter(L => { try { return JSON.parse(L).t >= cutoff; } catch (e) { return false; } });
        try { writeFileAtomic(HIST, lines.join('\n') + '\n'); } catch (e) {}
      }
    });
  });
  req.on('error', e => {
    const cur = loadCurrent(); cur.ok = false; cur.status = 'neterr'; cur.checked_at = Date.now(); writeCurrent(cur);
  });
  req.setTimeout(15000, () => { req.destroy(); });
  req.end();
}

try { main(); } catch (e) { /* 폴러는 절대 죽지 않게 */ }
