import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const own=fileURLToPath(import.meta.url);
export const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
export function safe(root,rel,{exists=true}={}) {
  if(typeof rel!=='string'||!rel.trim()) throw Error('Required path missing');
  const base=fs.realpathSync(root), full=path.resolve(base,rel);
  const inside=p=>p.startsWith(base+path.sep);
  if(!inside(full)) throw Error(`Path escapes Knowledge: ${rel}`);
  let parent=full;
  while(!fs.existsSync(parent)) { const next=path.dirname(parent);if(next===parent)throw Error('No safe ancestor');parent=next; }
  const actual=fs.realpathSync(parent);
  if(actual!==base&&!inside(actual)) throw Error(`Link escapes Knowledge: ${rel}`);
  // Reject reparse paths altogether for writes and evidence, including internal links.
  for(let part=parent;part!==base;part=path.dirname(part)) if(fs.lstatSync(part).isSymbolicLink()) throw Error(`Linked evidence path: ${rel}`);
  if(exists&&!fs.existsSync(full))throw Error(`Missing evidence: ${rel}`);
  return full;
}
const read=(root,rel)=>JSON.parse(fs.readFileSync(safe(root,rel),'utf8').replace(/^\uFEFF/,''));
const relative=(root,p)=>path.relative(root,p).split(path.sep).join('/');
const record=(root,rel)=>{const full=safe(root,rel,{exists:false});return {path:relative(root,full),exists:fs.existsSync(full),sha256:fs.existsSync(full)?sha(fs.readFileSync(full)):null};};
const rulePaths=['system/protocols/INGEST_PROTOCOL.md','system/protocols/SCORING_SYSTEM.md','raw-sources/README.md','wiki/README.md','system/maintenance/checklists/source-content-audit-standard-v1.md','system/maintenance/checklists/ingest-control.ps1','system/maintenance/checklists/raw-review-control.mjs','system/maintenance/checklists/ingest-review.mjs','system/maintenance/checklists/render-ingest-package.ps1','system/registry/ingest-semantic-review-policy.json','system/maintenance/checklists/raw-standard-v2.md','system/maintenance/checklists/raw-writing-v2.md','system/maintenance/checklists/raw-quality.mjs'];
function collectReferences(value,result=new Set()) {
  if(Array.isArray(value)){for(const item of value)collectReferences(item,result);return result;}
  if(value&&typeof value==='object')for(const [key,v] of Object.entries(value)){
    if(typeof v==='string'&&/^(?:Clippings|raw-sources|wiki|domains|groups|system)\/.+\.(?:md|json|png|jpg|jpeg|webp|svg|txt)$/i.test(v)&& !/(?:^|\/)run\.json$/.test(v))result.add(v);
    else if(v&&typeof v==='object')collectReferences(v,result);
  }
  return result;
}
export function snapshot(root,run,stage,semantic={}) {
  const refs=new Set(run.items.filter(x=>typeof x==='string'&&/^(Clippings|raw-sources)\//.test(x)));
  if(run.raw_v2_migration){
    refs.add('system/maintenance/checklists/migrate-raw-v2.mjs');
    refs.add(run.raw_v2_migration.intent_path);
    refs.add(path.posix.join(path.posix.dirname(run.package_data.path),'raw-v2-migration.json'));
  }
  if(stage!=='scoring')for(const a of run.artifacts??[])refs.add(a.path);
  for(const ref of collectReferences(semantic))refs.add(ref);
  if(stage!=='scoring')for(const audit of run.content_audits??[]){refs.add(audit.path);for(const ref of collectReferences(read(root,audit.path)))refs.add(ref);}
  for(const rule of rulePaths)if(fs.existsSync(safe(root,rule,{exists:false})))refs.add(rule);
  const records=[...refs].sort().map(rel=>record(root,rel));
  // Earlier judgments refer to the observed Wiki version; fusion may replace it.
  if(['scoring','stage1','stage2'].includes(stage))for(let i=0;i<records.length;i++){
    const r=records[i];if(!r.path.startsWith('wiki/')||r.path==='wiki/README.md'||!r.exists)continue;
    const snapshotPath=path.posix.join(path.posix.dirname(run.package_data.path),'evidence',r.sha256+'.md');
    const destination=safe(root,snapshotPath,{exists:false});fs.mkdirSync(path.dirname(destination),{recursive:true});
    if(!fs.existsSync(destination))fs.copyFileSync(safe(root,r.path),destination);
    if(sha(fs.readFileSync(destination))!==r.sha256)throw Error('Frozen Wiki evidence drift');
    records[i]={...record(root,snapshotPath),source_path:r.path,source_sha256:r.sha256};
  }
  for(const r of records)if(!r.exists&&!(stage==='stage2'&&r.path.startsWith('wiki/')))throw Error(`Missing stage evidence: ${r.path}`);
  return records;
}
export function verifyRecords(root,records) {
  const errors=[];
  for(const old of records){const current=record(root,old.path);if(current.exists!==old.exists||current.sha256!==old.sha256)errors.push(old.path);}
  if(errors.length)throw Error(`Evidence changed; re-evaluate affected section: ${errors.join(', ')}`);
  return {status:'verified',file_count:records.length};
}
export function verifySection(root,run,stage,{afterWriting=false}={}) {
  const data=read(root,run.package_data.path), section=data.sections[stage];
  if(!section||section.status!=='sealed'||!Array.isArray(section.derived.dependencies))throw Error(`Unsealed or unbound section: ${stage}`);
  const records=section.derived.dependencies.filter(r=>!(afterWriting&&stage==='stage2'&&!r.exists&&r.path.startsWith('wiki/')));
  verifyRecords(root,records);
  if(!afterWriting)verifyRecords(root,records.filter(r=>r.source_path).map(r=>({path:r.source_path,exists:true,sha256:r.source_sha256})));
  return {status:'verified',file_count:records.length};
}
const cell=x=>String(x??'').replaceAll('|','\\|').replace(/\r?\n/g,'<br>');
const labels={source:'来源',total:'评分',decision:'处理决定',confidence:'把握程度',evidence:'判断依据',artifact:'Wiki页面',knowledge_summary:'本批知识增量',source_boundary:'来源与适用边界',disposition:'实际处置',verification:'验证结果',before:'拆分前',after:'拆分后',reason:'拆分原因',content_destination:'内容去向',source_destination:'来源去向',stage:'阶段',kind:'类型',detail:'具体情况'};
const table=(rows,columns)=>rows.length?['| '+columns.map(c=>labels[c]??c).join(' | ')+' |','| '+columns.map(()=>'---').join(' | ')+' |',...rows.map(r=>'| '+columns.map(c=>cell(r[c])).join(' | ')+' |')].join('\n'):'本项无记录。';
function link(root,out,rel,label=rel){safe(root,rel);return `[${String(label).replace(/[\[\]]/g,'')}](${path.relative(path.dirname(out),safe(root,rel)).split(path.sep).map(encodeURIComponent).join('/')})`;}
function git(root,args){return execFileSync('git',['-C',root,'-c','core.quotepath=false',...args],{encoding:'utf8',maxBuffer:32*1024*1024}).trimEnd();}
function assertAncestry(root,from,to){if(!/^[a-f0-9]{40}$/i.test(from??'')||!/^[a-f0-9]{40}$/i.test(to??''))throw Error('Checkpoint revisions must be full Git hashes');git(root,['merge-base','--is-ancestor',from,to]);}
function changedWiki(root,base){return [...new Set([...git(root,['diff','--name-only',base,'--','wiki']).split('\n'),...git(root,['ls-files','--others','--exclude-standard','--','wiki']).split('\n')])].filter(x=>x&&x!=='wiki/README.md'&&!x.endsWith('.template.md')).sort();}
export function verifyCheckpoint(root,runPath,stage,revision){
 root=fs.realpathSync(root);runPath=relative(root,safe(root,runPath));
 const run=read(root,runPath),data=read(root,run.package_data.path),stages=stage==='stage1'?['scoring','stage1']:['scoring','stage1','stage2','stage3','gate_audit'];
 const refs=new Set([runPath,run.package_data.path,...run.items.filter(x=>typeof x==='string'&&/^(Clippings|raw-sources)\//.test(x)),...(run.artifacts??[]).map(a=>a.path)]);
 for(const key of stages){if(run.packages[key])refs.add(run.packages[key].path);for(const r of data.sections[key]?.derived.dependencies??[])if(r.exists)refs.add(r.path);}
 if(stage==='stage3'){for(const w of changedWiki(root,run.base_revision))refs.add(w);if(run.packages.maintenance)refs.add(run.packages.maintenance.path);for(const b of run.backtests??[])refs.add(b.path);}
 for(const rel of refs){safe(root,rel,{exists:false});if(!fs.existsSync(safe(root,rel,{exists:false}))){let present=false;try{git(root,['cat-file','-e',`${revision}:${rel}`]);present=true;}catch{}if(present)throw Error('Checkpoint still contains deleted file: '+rel);continue;}
  let committed;try{committed=git(root,['rev-parse',`${revision}:${rel}`]);}catch{throw Error('Checkpoint missing evidence: '+rel);}
  const current=git(root,['hash-object','--path='+rel,rel]);if(current!==committed)throw Error('Checkpoint differs from current evidence: '+rel);
 }
 return {status:'verified',stage,revision,file_count:refs.size};
}
export function render(root,runPath,output) {
  root=fs.realpathSync(root);const run=read(root,runPath);
  if(![7,8].includes(run.schema_version))throw Error('Review v2 requires run schema 7 or 8');
  if(!['stage3_completed','awaiting_final_review'].includes(run.status))throw Error('Final review requires completed content stages');
  assertAncestry(root,run.base_revision,run.commits.stage1);assertAncestry(root,run.commits.stage1,run.commits.stage3);
  const out=safe(root,output,{exists:false}),runDir=path.dirname(safe(root,runPath));
  if(path.dirname(out)!==runDir)throw Error('Final report must be a direct run-local file');
  const data=read(root,run.package_data.path);
  if(data.schema_version!==2||data.renderer_version!=='ingest-package-renderer-v2')throw Error('Unsupported package semantics');
  for(const stage of ['scoring','stage1','stage2','stage3','gate_audit'])verifySection(root,run,stage,{afterWriting:true});
  const refs=new Set([run.package_data.path]);
  for(const p of Object.values(run.packages)){if(!p)throw Error('Final report requires all recorded packages');const now=record(root,p.path);if(now.sha256!==p.sha256)throw Error(`Package drift: ${p.path}`);refs.add(p.path);}
  for(const section of Object.values(data.sections))for(const r of section.derived.dependencies??[])if(r.exists||fs.existsSync(safe(root,r.path,{exists:false})))refs.add(r.path);
  const wikiPaths=changedWiki(root,run.base_revision);
  for(const w of wikiPaths)refs.add(w);
  for(const w of wikiPaths){const rows=data.sections.stage3.semantic.rows.filter(row=>row.artifact===w);if(!rows.length||rows.some(row=>!row.knowledge_summary?.trim()))throw Error(`Actual Wiki change lacks knowledge explanation: ${w}`);}
  for(const b of run.backtests??[]){refs.add(b.path);for(const r of collectReferences(read(root,b.path)))refs.add(r);}
  const mode=run.review_policy==='interactive'?'标准消化':'自动消化';
  const lines=[`# ${mode} · 最终内容审核`,'',`批次：${run.batch_id}。状态：awaiting_final_review。内容执行完成，尚待用户批准本报告及所引用版本。`,'', '## 1. 评分结果','',data.sections.scoring.semantic.summary,'',table(data.sections.scoring.semantic.rows,['source','total','decision','confidence','evidence']),'','## 2. 新增 raw 内容',''];
  for(const row of data.sections.stage1.semantic.rows){if(!row.raw)throw Error('Raw row missing path');lines.push(`### ${row.raw}`,'',row.content_summary??row.writing_skeleton,'',`保真：${row.coverage}；边界：${row.boundary}；处置：${row.disposition}。`,'',link(root,out,row.raw,'查看完整 raw'), '');}
  if(!data.sections.stage1.semantic.rows.length)lines.push('本批无新增 raw。','');
  lines.push('## 3. Wiki 补充与融合','',data.sections.stage3.semantic.summary,'',table(data.sections.stage3.semantic.rows,['artifact','knowledge_summary','source_boundary','disposition','verification']),'');
  for(const w of wikiPaths){const diff=git(root,['diff','--no-ext-diff','--no-color',run.base_revision,'--',w]);const diffRel=relative(root,path.join(runDir,'diffs',sha(w).slice(0,16)+'.diff.txt'));const file=safe(root,diffRel,{exists:false});fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,diff+'\n');refs.add(diffRel);lines.push(`### ${w}`,'',fs.existsSync(safe(root,w,{exists:false}))?link(root,out,w,'查看完整 Wiki'):'该页已删除；请检查拆分去向。','',link(root,out,diffRel,'查看本批完整差异'),'');}
  if(!wikiPaths.length)lines.push('本批没有实际 Wiki 正文差异。','');
  lines.push('## 4. Wiki 拆分结果','');
  const splits=data.sections.stage3.semantic.splits;
  if(!Array.isArray(splits))throw Error('stage3.semantic.splits must explicitly list completed splits or []');
  if(!splits.length)lines.push('本批无已执行拆分。');
  for(const split of splits){for(const key of ['before','after','reason','content_destination','source_destination','verification'])if(!split[key])throw Error(`Split result missing ${key}`);lines.push('',table([split],['before','after','reason','content_destination','source_destination','verification']));}
  lines.push('','## 5. 回测结果','');
  const required=run.counts.required_backtest_anchors??[];
  lines.push(`触发依据：raw 数量 ${run.counts.before} → ${run.counts.after}；当前合同要求跨越的锚点：${required.join(', ')||'无'}。`,'');
  if(!required.length)lines.push('状态：not_triggered。没有触发本次锚点回测；不代表全库质量通过。');
  for(const anchor of required){const b=run.backtests.find(b=>b.anchor===anchor);if(!b)throw Error(`Required backtest not_run: ${anchor}`);const receipt=read(root,b.path);if(record(root,b.path).sha256!==b.sha256)throw Error('Backtest receipt drift');lines.push(`- 锚点 ${anchor}：${receipt.status??'not_run'}；${link(root,out,b.path,'查看范围、结果与修复证据')}。`);}
  lines.push('','## 6. 例外、未消费与待决定','');
  const exceptions=[];for(const [stage,section] of Object.entries(data.sections))for(const field of ['semantic_exceptions','unresolved_risks','structure_change_requests','micro_failures','unconsumed'])for(const item of section.semantic[field]??[])exceptions.push({stage,kind:field,detail:typeof item==='string'?item:JSON.stringify(item)});
  lines.push(table(exceptions,['stage','kind','detail']),'','## 7. 已审结果、恢复与版本','',`Stage1：${run.commits.stage1}；Stage3：${run.commits.stage3}。`,'');
  for(const [stage,approval] of Object.entries(run.approvals??{}))if(approval)lines.push(`- ${stage} 已在标准阶段审核：${approval.sha256}；未变内容可复用，该记录不代替本批最终闭合。`);
  for(const [stage,p] of Object.entries(run.packages))lines.push(`- ${stage}：${link(root,out,p.path)}。`);
  const manifestPath=relative(root,path.join(runDir,'final-review-content.json'));
  lines.push('',`批准绑定本报告字节及 ${link(root,out,run.package_data.path,'已封存语义')} 和内容版本清单。任一相关正文或规则变化均需复验。`,'','通过 verify-final-review 后，用户批准当前 SHA-256，再执行 finish。');
  const text=lines.join('\n')+'\n';fs.writeFileSync(out,text);
  const manifest={schema_version:2,batch_id:run.batch_id,review_path:relative(root,out),review_sha256:sha(text),base_revision:run.base_revision,stage1_revision:run.commits.stage1,stage3_revision:run.commits.stage3,wiki_paths:wikiPaths,files:[...refs].sort().map(rel=>record(root,rel))};
  fs.writeFileSync(safe(root,manifestPath,{exists:false}),JSON.stringify(manifest,null,2)+'\n');
  return {path:relative(root,out),sha256:sha(text),content_manifest:manifestPath,content_manifest_sha256:record(root,manifestPath).sha256};
}
export function verify(root,runPath){const run=read(root,runPath),f=run.final_review;const m=read(root,f.content_manifest);if(record(root,f.content_manifest).sha256!==f.content_manifest_sha256)throw Error('Content manifest drift');if(m.batch_id!==run.batch_id||m.review_path!==f.path||m.review_sha256!==f.sha256)throw Error('Review identity mismatch');if(m.base_revision!==run.base_revision||m.stage1_revision!==run.commits.stage1||m.stage3_revision!==run.commits.stage3)throw Error('Checkpoint identity changed');if(record(root,f.path).sha256!==f.sha256)throw Error('Final report drift');if(JSON.stringify(changedWiki(root,run.base_revision))!==JSON.stringify(m.wiki_paths))throw Error('Wiki change scope drift');verifyRecords(root,m.files);for(const s of ['scoring','stage1','stage2','stage3','gate_audit'])verifySection(root,run,s,{afterWriting:true});return {status:'verified',sha256:f.sha256,content_manifest_sha256:f.content_manifest_sha256,file_count:m.files.length};}
if(process.argv[1]&&path.resolve(process.argv[1])===own){try{const [action,...argv]=process.argv.slice(2),args={};for(let i=0;i<argv.length;i+=2){if(!argv[i].startsWith('--')||argv[i+1]===undefined)throw Error('Expected --key value');args[argv[i].slice(2)]=argv[i+1];}const root=path.resolve(args.root??path.join(path.dirname(own),'../../..'));let result;if(action==='render')result=render(root,args.run,args.output);else if(action==='verify')result=verify(root,args.run);else if(action==='snapshot')result=snapshot(root,read(root,args.run),args.stage,read(root,args.semantic));else if(action==='verify-checkpoint')result=verifyCheckpoint(root,args.run,args.stage,args.revision);else if(action==='verify-section')result=verifySection(root,read(root,args.run),args.stage,{afterWriting:args['after-writing']==='true'});else throw Error('Unknown review action');console.log(JSON.stringify(result));}catch(e){console.error('INGEST_REVIEW_FAILED: '+e.message);process.exitCode=1;}}
