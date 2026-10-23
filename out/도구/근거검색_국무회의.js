// 로컬 국무회의 아카이브(읽기 전용)에서 사업별 주제어로 발언·안건을 찾아 out/중간기록/3_근거찾기_국무회의.md에 쓴다.
// 외부 전송 없음. 검색어는 사업 자료의 문장이 아니라 일반 주제어만 쓴다. 분류(stc 등)는 다시 판정하지 않는다.
// 사용: node 근거검색_국무회의.js <bundle.json> <출력.md> [시작일=2025-06-01]
const fs = require('fs');
const [bundlePath, outPath, since = '2025-06-01'] = process.argv.slice(2);
const d = JSON.parse(fs.readFileSync(bundlePath, 'utf8'));
const urlOf = Object.fromEntries(d.meetings.map(m => [m.key, m.url]));
const sessionOf = Object.fromEntries(d.meetings.map(m => [m.key, `${m.year}년 제${m.session}회`]));

// 사업 번호 → 사업명, 주제어(일반 주제어)
const jobs = [
  [1, '산업기술정책연구조사(R&D) 가. 산업기술정책기획', ['산업기술정책']],
  [2, '산업기술정책연구조사(R&D) 나. 산업기술전략수립', ['산업기술 전략', '산업기술전략']],
  [3, '산업기술정책연구조사(R&D) 다. 산업기술R&D통계조사 및 성과분석', ['R&D 통계', 'R&D 성과', '연구개발 성과']],
  [4, '산업기술혁신 문화환경조성', ['산업기술 문화', '산업기술문화']],
  [5, '국가첨단전략산업육성보호기반조성사업', ['첨단전략산업']],
  [6, '첨단반도체양산연계형미니팹기반구축(R&D)', ['미니팹']],
  [7, '국가첨단전략산업특화단지연대협력지원사업(R&D)', ['특화단지']],
  [8, '국가첨단전략산업 소부장 중소중견기업 투자지원금 사업', ['소부장', '소재부품장비', '소재·부품·장비']],
  [9, '반도체소재부품시험평가센터구축', ['반도체']],
  [10, '반도체첨단패키징실증센터구축', ['패키징']],
];
const MAX = 4;
const out = [];
out.push('# 3. 근거 찾기: 국무회의 (로컬 아카이브)');
out.push('');
out.push(`- 자료: 정책브리핑(문화체육관광부) 국무회의 브리핑 첨부 문서를 가공한 아카이브. 공공누리 제1유형(출처표시). 범위 ${d.meta.range[0]} ~ ${d.meta.range[1]}.`);
out.push(`- 검색 범위: ${since} 이후(현 정부). 주제어가 발언 본문 또는 안건 제목에 들어 있는 것만 찾았다. 분류는 다시 판정하지 않았다.`);
out.push('- 주의: 국무회의 의안 심의는 비공개다. 안건은 "상정·의결된 것"까지만 알 수 있고 논의 내용은 알 수 없다. 발언은 모두발언 등으로 공개된 것만 있다.');
out.push('- 각 항목의 출처는 해당 회차의 정책브리핑 링크다. 발언은 앞뒤를 줄인 발췌다(…).');
out.push('');
const summary = [];
for (const [no, name, kws] of jobs) {
  const hasKw = s => kws.some(k => s.includes(k));
  const utt = d.utterances.filter(u => u.date >= since && hasKw(u.text)).sort((a, b) => b.date.localeCompare(a.date));
  const ag = d.agenda.filter(a => a.date >= since && hasKw(a.title)).sort((a, b) => b.date.localeCompare(a.date));
  summary.push(`${no}번: 발언 ${utt.length}건, 안건 ${ag.length}건`);
  out.push(`## 사업 ${no}. ${name}`);
  out.push('');
  out.push(`- 주제어: ${kws.join(', ')}`);
  out.push(`- 찾은 수: 발언 ${utt.length}건, 안건 ${ag.length}건 (아래에는 최신 ${MAX}건까지)`);
  out.push('');
  if (!utt.length && !ag.length) { out.push('찾은 근거가 없다. 지어내지 않고 비워 둔다.'); out.push(''); continue; }
  if (utt.length) {
    out.push('### 발언');
    out.push('');
    out.push('| 날짜 | 회차 | 발언자 | 발췌 | 출처 |');
    out.push('|---|---|---|---|---|');
    for (const u of utt.slice(0, MAX)) {
      const k = kws.find(x => u.text.includes(x));
      const i = u.text.indexOf(k);
      const a = Math.max(0, i - 80), b = Math.min(u.text.length, i + k.length + 140);
      const ex = (a > 0 ? '…' : '') + u.text.slice(a, b).replace(/\s+/g, ' ').replace(/\|/g, '/') + (b < u.text.length ? '…' : '');
      out.push(`| ${u.date} | ${sessionOf[u.meetingKey] || u.meetingKey} | ${u.speaker} | ${ex} | [정책브리핑](${urlOf[u.meetingKey] || ''}) |`);
    }
    out.push('');
  }
  if (ag.length) {
    out.push('### 안건 (상정·의결)');
    out.push('');
    out.push('| 날짜 | 회차 | 의안 | 제출 | 결과 | 출처 |');
    out.push('|---|---|---|---|---|---|');
    for (const a of ag.slice(0, MAX)) {
      out.push(`| ${a.date} | ${sessionOf[a.meetingKey] || a.meetingKey} | ${a.title.replace(/\|/g, '/')} (${a.category}) | ${a.ministry} | ${a.cabinetResult || '〔확인필요〕'} | [정책브리핑](${urlOf[a.meetingKey] || ''}) |`);
    }
    out.push('');
  }
}
fs.writeFileSync(outPath, out.join('\n') + '\n', 'utf8');
console.log(summary.join('\n'));
