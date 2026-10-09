import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const VERSION = 'knowledge-health/1';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const rel = value => value.replaceAll('\\', '/');
function safe(root, value) {
  const resolved = path.resolve(root, value);
  if (resolved !== root && !resolved.startsWith(root + path.sep)) throw Error(`Path escapes Knowledge: ${value}`);
  let cursor = resolved;
  while (!fs.existsSync(cursor) && cursor !== root) cursor = path.dirname(cursor);
  const real = fs.realpathSync(cursor);
  if (real !== root && !real.startsWith(root + path.sep)) throw Error(`Symlink escapes Knowledge: ${value}`);
  return resolved;
}
function files(root, prefix) {
  const target = safe(root, prefix);
  if (!fs.existsSync(target)) return [];
  const stat = fs.lstatSync(target);
  if (stat.isSymbolicLink()) throw Error(`Health refuses linked input: ${prefix}`);
  if (!stat.isDirectory()) return [rel(path.relative(root, target))];
  return fs.readdirSync(target).sort().flatMap(name => files(root, rel(path.join(prefix, name))));
}
function json(root, name, fallback = null) {
  const full = safe(root, name);
  return fs.existsSync(full) ? JSON.parse(fs.readFileSync(full, 'utf8').replace(/^\uFEFF/, '')) : fallback;
}
function manifest(root, prefixes) {
  return Object.fromEntries([...new Set(prefixes.flatMap(p => files(root, p)))].sort().map(p => [p, sha(fs.readFileSync(safe(root, p)))]));
}
function finding(code, file, detail, severity = 'warning', kind = 'mechanical') {
  return { code, path: file, detail, severity, kind, owner: kind === 'semantic_review' ? 'knowledge-content-owner' : 'knowledge-maintainer', action: kind === 'semantic_review' ? 'Review meaning and applicability; preserve original decision until re-reviewed.' : 'Inspect affected authority and repair only within authorized scope, then recheck.', authorization: /^(wiki|raw-sources|Clippings|domains|groups)\//.test(file) ? 'content-owner authorization required for edits' : 'explicit derived-maintenance scope required for writes' };
}
const definitions = [
  ['graph', 'check-knowledge-graph.ps1', [], ['wiki','raw-sources','domains','Clippings','system/registry']],
  ['page_health', 'check-wiki-page-health.ps1', ['-Mode','Report'], ['wiki','system/maintenance/wiki-split-closures.json']],
  ['governance', 'check-wiki-governance.ps1', ['-Mode','Report'], ['wiki','raw-sources','domains','NOW.md','system/registry/KNOWLEDGE_STATUS.md','system/maintenance/wiki-semantic-review-closures.json','system/maintenance/wiki-split-closures.json']],
  ['groups', 'check-wiki-groups.ps1', ['-Mode','Enforce','-RequireGroupsField','-RejectLegacyThemes'], ['wiki','groups','system/registry','system/maintenance']],
  ['group_navigation', 'sync-wiki-groups.ps1', ['-Mode','Check'], ['wiki','groups','system/registry','system/maintenance']],
  ['quick_reference', 'sync-quick-reference-groups.ps1', ['-Mode','Check'], ['wiki','groups','system/registry','system/maintenance']],
  ['source_ledgers', 'sync-wiki-source-ledgers.ps1', ['-Mode','Check'], ['wiki','raw-sources','system/registry']],
  ['link_anchors', 'sync-wiki-link-anchors.ps1', ['-Mode','Check'], ['wiki','system/maintenance/wiki-related-page-anchor-overrides.json']],
  ['capacity', 'sync-capacity-risks.ps1', ['-Mode','Check'], ['wiki','NOW.md','system/registry','system/maintenance/wiki-split-closures.json']],
  ['clipping_identity', 'sync-clipping-migration-hashes.ps1', ['-Mode','Check'], ['Clippings','raw-sources','system/registry/clipping-path-migrations.json']],
  ['query_contract', 'run-query-contract.ps1', [], ['README.md','AGENTS.md','COMMAND_MANUAL.md','system/README.md','system/integrations','system/query']]
];
export function runHealth({root, scope = 'affected', previous = null, changed = [], now = new Date().toISOString(), events = [], host = process.platform === 'win32' ? 'powershell' : 'pwsh', only = null} = {}) {
  const start = performance.now(); root = fs.realpathSync(root);
  if (!['affected','full'].includes(scope)) throw Error('scope must be affected or full');
  const common = manifest(root, ['system/maintenance/checklists','system/protocols','wiki/README.md','raw-sources/README.md','groups/README.md','domains/README.md']);
  const ruleHash = sha(JSON.stringify(common));
  const checks = [];
  for (const [id, script, args, dependencies] of definitions) {
    if (only && !only.includes(id)) continue;
    const inputs = manifest(root, dependencies);
    const fingerprint = sha(JSON.stringify({version:VERSION, ruleHash, inputs}));
    const old = previous?.checks?.find(c => c.id === id);
    if (scope === 'affected' && previous?.engine === VERSION && old?.fingerprint === fingerprint && old.execution !== 'tool_failed' && old.complete === true && old.executed_at && Date.parse(now) >= Date.parse(old.executed_at) && Date.parse(now) - Date.parse(old.executed_at) < 86400000) {
      checks.push({...old, execution:'reused', reused_from: previous.generated_at, elapsed_ms:0}); continue;
    }
    const before = performance.now();
    const scriptPath = safe(root, `system/maintenance/checklists/${script}`);
    const quote = v => "'" + v.replaceAll("'", "''") + "'";
    const command = `$ProgressPreference = 'SilentlyContinue'; [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false); & ${quote(scriptPath)} ${args.map(v=>v.startsWith('-')?v:quote(v)).join(' ')}; exit $LASTEXITCODE`;
    const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => key.toUpperCase() !== 'PSMODULEPATH'));
    const result = spawnSync(host, ['-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',Buffer.from(command,'utf16le').toString('base64')], {cwd:root,env,encoding:'utf8',timeout:180000,maxBuffer:16*1024*1024,windowsHide:true});
    let parsed = null; try { parsed = JSON.parse(result.stdout?.trim().replace(/^\uFEFF/,'')); } catch {}
    const failedTool = Boolean(result.error) || result.status === null || ![0,1,2].includes(result.status) || (result.status === 0 && id !== 'query_contract' && !parsed);
    let findings = [...(parsed?.findings ?? []), ...(parsed?.failures ?? []).map(f=>({...f,severity:'error'})), ...(Array.isArray(parsed?.warnings)?parsed.warnings:[]).map(f=>({...f,severity:'warning'}))].map(f=>({...finding(f.code ?? id, f.path ?? '', f.detail ?? f.details ?? JSON.stringify(f), f.severity ?? 'warning', /candidate|semantic|capacity|split/.test(f.code ?? '') ? 'semantic_review':'mechanical'), ...(f.target_path?{target_path:f.target_path}:{})}));
    if ((failedTool || result.status !== 0 || parsed?.status === 'failed') && !findings.length) findings.push(finding(failedTool?'tool_execution_failed':`${id}_not_current`, `system/maintenance/checklists/${script}`, result.error?.message ?? (result.stderr || result.stdout || `No valid structured result; exit=${result.status}`).trim(), 'error'));
    checks.push({id, fingerprint, input_count:Object.keys(inputs).length, dependencies, execution:failedTool?'tool_failed':'executed', complete:!failedTool, status:failedTool?'tool_failed':result.status!==0||findings.some(f=>f.severity==='error')?'failed':findings.length?'needs_review':'passed', exit_code:result.status, executed_at:now, elapsed_ms:Math.round(performance.now()-before), findings, details: parsed ? {status:parsed.status,summary:parsed.summary} : result.stdout?.trim().slice(0,4000), invalidation: !old?'no_previous_evidence':old.fingerprint!==fingerprint?'inputs_or_rules_changed':'full_or_expired'});
  }
  const observations = [];
  const registry = json(root,'system/registry/ingest-auto-review-state.json');
  const runFiles = files(root,'system/maintenance/ingest-runs').filter(p=>p.endsWith('/run.json')&&!p.includes('/revisions/'));
  const runs = runFiles.map(p=>({path:p, run:json(root,p)}));
  const active = runs.filter(({run})=>!['completed','abandoned'].includes(run.status));
  // Standard runs do not occupy the automatic-review registry. Missing legacy
  // policy keeps its historical deferred interpretation for registry auditing.
  const automatic = active.filter(({run})=>run.review_policy !== 'interactive');
  const standard = active.filter(({run})=>run.review_policy === 'interactive');
  if ((!registry && automatic.length) || (registry && ((registry.status==='inactive' && automatic.length) || (registry.status!=='inactive' && (!automatic.some(({run})=>run.batch_id===registry.batch_id) || automatic.some(({run})=>run.batch_id!==registry.batch_id)))))) observations.push(finding('run_registry_drift','system/registry/ingest-auto-review-state.json',`registry=${registry?.status ?? 'missing'}; automatic active runs=${automatic.map(r=>r.path).join(',')}`,'error'));
  for (const item of standard) observations.push({...finding('standard_run_active',item.path,`Standard run ${item.run.batch_id}: ${item.run.status}; automatic registry is not used.`,'info'), action:'Read this run manifest for the current stage and required approval; do not activate the automatic registry.'});
  if (registry?.last_completed_batch && !runs.some(r=>path.basename(path.dirname(r.path))===registry.last_completed_batch && r.run.status==='completed')) observations.push(finding('last_completed_run_missing','system/registry/ingest-auto-review-state.json',registry.last_completed_batch,'error'));
  for(const p of ['NOW.md','system/registry/KNOWLEDGE_STATUS.md']) {
    if(!fs.existsSync(safe(root,p))) { observations.push(finding('status_summary_missing',p,'Derived summary is unavailable.')); continue; }
    const text=fs.readFileSync(safe(root,p),'utf8');
    if(registry?.status==='inactive' && !standard.length && /(?:当前|状态|本轮|最近|等待)[^\n]*(?:待.*审核|等待.*审核|awaiting_review)/i.test(text)) observations.push(finding('status_summary_review_candidate',p,'Registry is inactive but summary contains awaiting-review language; inspect current section, do not rewrite historical review.','warning'));
  }
  for(const registryPath of ['system/maintenance/wiki-semantic-review-closures.json','system/maintenance/wiki-split-closures.json','system/maintenance/health-issues.json']) {
    const doc=json(root,registryPath); if(!doc) continue;
    const entries=[...(doc.records??[]),...(doc.domain_reviews??[]),...(doc.conflict_reviews??[]),...(doc.issues??[]),...(doc.source_marker_policy?[{...doc.source_marker_policy,path:'wiki',id:'source_marker_policy'}]:[])];
    for(const entry of entries) {
      const bound=entry.input_hashes; const reasons=[];
      if(!bound || !Object.keys(bound).length) reasons.push('legacy closure has no input version binding; cannot certify still current');
      else for(const [p,h] of Object.entries(bound)) if(!fs.existsSync(safe(root,p)) || sha(fs.readFileSync(safe(root,p)))!==h) reasons.push(`input changed: ${p}`);
      if(entry.rule_hash && entry.rule_hash!==ruleHash) reasons.push('rules changed');
      if(entry.review_by && (!Number.isFinite(Date.parse(entry.review_by)) || Date.parse(entry.review_by)<=Date.parse(now))) reasons.push('review date reached');
      if(entry.review_events?.some(e=>events.includes(e))) reasons.push('review event reached');
      if(changed.some(p=>p===entry.path || entry.path==='wiki'&&p.startsWith('wiki/'))) reasons.push('affected content changed');
      if(!entry.review_by && !entry.review_events?.length) reasons.push('review_when needs Agent interpretation; no machine-evaluable deadline or event');
      if(!entry.rule_hash) reasons.push('no rule version binding');
      const state=reasons.length?'review_required':entry.state==='resolved'||entry.state==='completed'?'resolved':'deferred_not_due';
      observations.push({...finding(reasons.length?'closure_recheck_required':'closure_current',entry.path??registryPath, reasons.join('; ') || entry.reason || 'Version-bound closure is current.',reasons.length?'warning':'info','semantic_review'), disposition:state, registry:registryPath, review_when:entry.review_when??null});
    }
  }
  const findings=[...checks.flatMap(c=>c.findings),...observations];
  return {schema_version:1,engine:VERSION,generated_at:now,root,requested_scope:scope,scope_reason:scope==='full'?'Explicit full check; no reuse.':'Whole cross-page dependency modules rerun when any bound input changes; unchanged modules reused for at most 24h. No changed-file-only filtering.',changed_paths:changed,rule_hash:ruleHash,checks,findings,unchecked:['semantic truth, source fidelity and user acceptance require Agent/human review','historical artifact JSON beyond run manifests; use graph -IncludeHistoricalJson for explicit archival audit',...(only?['diagnostic module subset selected; not a complete health check']:[])],status:only?'partial':checks.some(c=>c.execution==='tool_failed')?'incomplete':findings.some(f=>f.severity==='error')?'issues_found':findings.some(f=>f.severity==='warning')?'needs_review':'mechanically_healthy',elapsed_ms:Math.round(performance.now()-start),writes_performed:false,summary:{executed:checks.filter(c=>c.execution==='executed').length,reused:checks.filter(c=>c.execution==='reused').length,tool_failed:checks.filter(c=>c.execution==='tool_failed').length,findings:findings.length}};
}
export function markdown(report) {
 const cell = value => String(value ?? '').replaceAll('|','\\|').replaceAll('\n','<br>');
 const html = value => String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
 const grouped = new Map();
 for (const f of report.findings) {
   const key=JSON.stringify([f.code,f.owner,f.authorization]);
   if(!grouped.has(key)) grouped.set(key,{code:f.code,owner:f.owner,authorization:f.authorization,items:[],actions:new Set()});
   const group=grouped.get(key);group.items.push(f);group.actions.add(f.action);
 }
 const summary=[...grouped.values()].map(g=>`| ${cell(g.code)} | ${g.items.length} | ${cell([...new Set(g.items.map(f=>f.disposition??f.severity))].join(', '))} | ${cell(g.owner)} | ${cell(g.authorization)} | ${cell([...g.actions].join(' '))} |`).join('\n');
 const details=[...grouped.values()].map(g=>`<details>\n<summary>${html(g.code)} — ${g.items.length} 项；${html(g.owner)}</summary>\n\n<pre>${html(JSON.stringify(g.items,null,2))}</pre>\n\n</details>`).join('\n\n');
 return `# Knowledge 健康检查\n\n状态：${report.status}；范围：${report.requested_scope}；版本：${report.engine}；耗时：${report.elapsed_ms} ms。\n\n${report.scope_reason}\n\n| 检查 | 执行 | 结果 | 毫秒 |\n|---|---|---|---|\n${report.checks.map(c=>`| ${c.id} | ${c.execution} | ${c.status} | ${c.elapsed_ms} |`).join('\n')}\n\n## 问题与处置\n\n共 ${report.findings.length} 项，按问题类型、owner 和授权范围汇总为 ${grouped.size} 组；数量不代表严重程度，复核候选不等于已确认错误。\n\n${summary ? '| 类型 | 数量 | 状态 | Owner | 写入授权 | 动作 |\n|---|---:|---|---|---|---|\n'+summary : '本次机械检查未发现问题。'}\n\n## 完整明细\n\n原始 findings 完整保留在 JSON；下方按同一分组折叠展示全部字段，不隐藏待复核项。\n\n${details}\n\n## 未检查\n\n${report.unchecked.map(s=>`- ${s}`).join('\n')}\n\n检查不修改知识、状态或历史证据；修复后重新检查，不把机械健康当作语义正确。\n`;
}

if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 try {
  const args=process.argv.slice(2); const value=k=>{const i=args.indexOf(k); return i<0?null:args[i+1];};
  const root=value('--root')??path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
  const previous=value('--previous')?json(fs.realpathSync(root),value('--previous')):null;
  const report=runHealth({root,scope:value('--scope')??'affected',previous,changed:args.flatMap((v,i)=>v==='--changed'?[args[i+1]]:[]),events:args.flatMap((v,i)=>v==='--event'?[args[i+1]]:[])});
  console.log(value('--format')==='markdown'?markdown(report):JSON.stringify(report,null,2));
  process.exitCode=report.status==='incomplete'?3:report.status==='issues_found'?2:0;
 } catch(e) {console.error(`KNOWLEDGE_HEALTH_FAILED: ${e.message}`);process.exitCode=3;}
}
