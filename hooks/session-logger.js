#!/usr/bin/env node
// Claude Code 세션 로거 — SessionStart/SessionEnd 훅에서 호출됨.
// 사용법: node session-logger.js <start|end>   (stdin으로 훅 JSON 수신)
// 로그: ~/.claude/session-log/YYYY-MM.md (월별 markdown)
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const LOG_DIR = path.join(os.homedir(), '.claude', 'session-log');
const STATE_DIR = path.join(LOG_DIR, 'state');

function readStdin() {
  try { return JSON.parse(fs.readFileSync(0, 'utf8')); } catch (e) { return {}; }
}

function fmt(d) {
  const p = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

// 트랜스크립트에 주입되는 비-프롬프트 라인들 (실측으로 확인된 프리픽스)
const NOISE_PREFIXES = [
  '<command-message>', '<local-command', '<system-reminder>',
  '<task-notification>', '<bash-', 'Caveat:', '[Request interrupted',
];

function main() {
  const mode = process.argv[2];
  const input = readStdin();
  const sid = input.session_id || 'unknown';
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const stateFile = path.join(STATE_DIR, sid + '.json');

  if (mode === 'start') {
    // SessionEnd를 못 받은 세션(강제 종료 등)의 고아 상태 파일 정리
    try {
      const cutoff = Date.now() - 30 * 864e5;
      for (const f of fs.readdirSync(STATE_DIR)) {
        const fp = path.join(STATE_DIR, f);
        try { if (fs.statSync(fp).mtimeMs < cutoff) fs.unlinkSync(fp); } catch (e) {}
      }
    } catch (e) {}
    // compact로 인한 재시작은 원래 시작 시각을 보존
    if (input.source === 'compact' && fs.existsSync(stateFile)) return;
    fs.writeFileSync(stateFile, JSON.stringify({
      start: Date.now(), cwd: input.cwd || '', source: input.source || ''
    }), 'utf8');
    return;
  }

  if (mode !== 'end') return;

  let state = null;
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); }
  catch (e) { /* 훅 추가 전에 시작된 세션 등 — 트랜스크립트 타임스탬프로 대체 */ }
  const cleanup = () => { try { fs.unlinkSync(stateFile); } catch (e) {} };

  let aiTitle = '';
  let customTitle = '';
  const prompts = [];
  let nPrompts = 0;
  let firstTs = null;
  try {
    const lines = fs.readFileSync(input.transcript_path, 'utf8').split('\n');
    for (const line of lines) {
      if (!line.trim()) continue;
      let o;
      try { o = JSON.parse(line); } catch (e) { continue; }
      if (o.type === 'ai-title' && o.aiTitle) aiTitle = o.aiTitle;
      if (o.type === 'custom-title' && o.customTitle) customTitle = o.customTitle;
      if (o.timestamp && !firstTs) firstTs = o.timestamp;
      if (o.type !== 'user' || o.isSidechain || o.isMeta || o.isCompactSummary || !o.message) continue;
      let text = '';
      const c = o.message.content;
      if (typeof c === 'string') text = c;
      else if (Array.isArray(c)) text = c.filter(p => p && p.type === 'text').map(p => p.text).join(' ');
      text = (text || '').trim();
      if (!text) continue;
      if (text.includes('<command-name>')) {
        // 슬래시 커맨드 호출 → "/명령 인자"를 프롬프트로 기록 (/goal 브리지 세션 등)
        const name = (text.match(/<command-name>([^<]*)<\/command-name>/) || [])[1] || '';
        const args = (text.match(/<command-args>([\s\S]*?)<\/command-args>/) || [])[1] || '';
        text = (name + ' ' + args).trim();
        if (!text) continue;
      } else if (NOISE_PREFIXES.some(p => text.startsWith(p))) {
        continue;
      }
      nPrompts++;
      if (prompts.length < 3) {
        const chars = Array.from(text.replace(/\s+/g, ' '));
        prompts.push(chars.length > 120 ? chars.slice(0, 120).join('') + '…' : chars.join(''));
      }
    }
  } catch (e) { /* 트랜스크립트 없음/읽기 실패 → 아래에서 빈 세션으로 처리 */ }

  const title = customTitle || aiTitle;
  // 프롬프트도 제목도 없는 세션(열자마자 닫음, 헬스체크 등)은 기록하지 않음
  if (nPrompts === 0 && !title) { cleanup(); return; }

  const end = new Date();
  const start = state ? new Date(state.start) : (firstTs ? new Date(firstTs) : null);
  let dur = '';
  if (start && !isNaN(start)) {
    const m = Math.max(0, Math.round((end - start) / 60000));
    dur = m >= 60 ? ` (${Math.floor(m / 60)}시간 ${m % 60}분)` : ` (${m}분)`;
  }
  const cwd = input.cwd || (state && state.cwd) || '?';

  const entryLines = [
    `## ${start && !isNaN(start) ? fmt(start) : '????'} → ${fmt(end)}${dur} — \`${cwd}\``,
    `**${title || '(제목 없음)'}**  ·  종료: ${input.reason || '?'} · 프롬프트 ${nPrompts}개 · \`${sid.slice(0, 8)}\``
  ];
  for (const p of prompts) entryLines.push(`- ${p}`);
  if (nPrompts > prompts.length) entryLines.push(`- … 외 ${nPrompts - prompts.length}개`);
  entryLines.push(`<!-- id:${sid} -->`); // 위젯 더블클릭 resume용 (마크다운에선 비표시)
  entryLines.push('');

  const month = `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}`;
  fs.appendFileSync(path.join(LOG_DIR, month + '.md'), entryLines.join('\n') + '\n', 'utf8');
  cleanup(); // 기록 성공 후에만 상태 파일 삭제 (종료 시 강제 킬에도 로그 유실 방지)
}

try { main(); } catch (e) { /* 세션 시작/종료를 절대 막지 않음 */ }
