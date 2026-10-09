// Explicit nonterminal deferred schema7 -> Raw v2 migration. No corpus writes.
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {safe,sha} from './ingest-review.mjs';
const statePath='system/registry/ingest-auto-review-state.json';
const json=(root,p)=>JSON.parse(fs.readFileSync(safe(root,p),'utf8').replace(/^\uFEFF/,''));
const bytes=(root,p)=>fs.readFileSync(safe(root,p));
const encode=x=>Buffer.from(JSON.stringify(x,null,2)+'\n');
const git=(root,...args)=>execFileSync('git',['-C',root,'-c','core.quotepath=false',...args],{encoding:'utf8',maxBuffer:32e6}).trimEnd();
const requireValue=(v,msg)=>{if(!v)throw Error(msg);};
const relative=(root,p)=>path.relative(root,p).split(path.sep).join('/');
const rawFiles=(root,rev)=>git(root,'ls-tree','-r','--name-only',rev,'--','raw-sources').split('\n').filter(p=>p.endsWith('.md')&&!p.endsWith('/README.md')&&!p.endsWith('.template.md'));
function atomic(root,p,b){const dest=safe(root,p,{exists:false}),tmp=dest+'.migration-tmp';fs.writeFileSync(tmp,b,{flag:'wx'});fs.renameSync(tmp,dest);}
function walk(root,folder){const result=[];for(const entry of fs.readdirSync(safe(root,folder),{withFileTypes:true})){const p=folder+'/'+entry.name;safe(root,p);if(entry.isDirectory()){if(entry.name!=='revisions')result.push(...walk(root,p));}else if(entry.isFile())result.push(p);}return result;}
function loadTransaction(root,runPath){const folder=path.posix.dirname(runPath),pointer=folder+'/raw-v2-migration.json',tx=json(root,pointer);requireValue(tx.run_path===runPath&&tx.state_path===statePath,'Migration identity mismatch');return {tx,pointer};}
export function checkpointBase(root,runPath){
 root=fs.realpathSync(root);runPath=relative(root,safe(root,runPath));
 const run=json(root,runPath);if(!run.raw_v2_migration)return run.base_revision;
 const {tx}=loadTransaction(root,runPath);
 requireValue(tx.status==='committed'&&run.schema_version===8&&run.raw_standard==='RAW_STANDARD_V2','Migration is not committed');
 requireValue(run.raw_v2_migration.transaction_sha256===sha(bytes(root,tx.intent_path)),'Migration intent drift');
 const intent=json(root,tx.intent_path);
 requireValue(intent.business_base===run.base_revision&&intent.checkpoint_base===run.raw_v2_migration.checkpoint_base&&intent.before_count===run.counts.before,'Migration baseline drift');
 git(root,'merge-base','--is-ancestor',intent.business_base,intent.checkpoint_base);
 for(const f of intent.snapshots)requireValue(sha(bytes(root,f.archive_path))===f.sha256,'Archived migration evidence drift: '+f.path);
 if(!run.raw_standard_checkpoint)return intent.checkpoint_base;
 const extension=run.raw_standard_checkpoint;
 requireValue(extension.path.startsWith(path.posix.dirname(runPath)+'/'),'Framework checkpoint must be run local');
 requireValue(sha(bytes(root,extension.path))===extension.sha256,'Framework checkpoint evidence drift');
 const evidence=json(root,extension.path);
 requireValue(evidence.batch_id===run.batch_id&&evidence.original_checkpoint===intent.checkpoint_base&&evidence.business_base===run.base_revision&&evidence.before_count===run.counts.before,'Framework checkpoint identity drift');
 verifyFrameworkDelta(root,evidence);
 git(root,'merge-base','--is-ancestor',evidence.to,git(root,'rev-parse','HEAD'));
 return evidence.to;
}
const frameworkPath=p=>/^(system\/maintenance\/checklists\/|tests\/|scripts\/|release-input\/)/.test(p)||['raw-sources/README.md','system/protocols/INGEST_PROTOCOL.md'].includes(p);
function verifyFrameworkDelta(root,e){
 requireValue(/^[a-f0-9]{40}$/.test(e.from)&&/^[a-f0-9]{40}$/.test(e.to)&&e.from!==e.to,'Invalid framework revisions');
 git(root,'merge-base','--is-ancestor',e.original_checkpoint,e.from);git(root,'merge-base','--is-ancestor',e.from,e.to);
 const paths=git(root,'diff','--name-only',e.from,e.to).split('\n').filter(Boolean).sort();
 requireValue(paths.length&&paths.every(frameworkPath),'Framework checkpoint includes corpus or other non-framework changes');
 requireValue(JSON.stringify(paths)===JSON.stringify(e.paths),'Framework path inventory drift');
 requireValue(JSON.stringify(rawFiles(root,e.from))===JSON.stringify(rawFiles(root,e.to)),'Framework update changed Raw inventory');
}
export function advanceCheckpoint(root,runPath,o={}){
 root=fs.realpathSync(root);runPath=relative(root,safe(root,runPath));
 const original=bytes(root,runPath),run=json(root,runPath),state=json(root,statePath);
 requireValue(sha(original)===o.runHash,'Expected run hash mismatch');
 requireValue(run.raw_v2_migration&&!run.raw_standard_checkpoint&&run.schema_version===8&&run.status==='running_scoring'&&!run.managed_task,'Framework advance needs reopened standalone migrated run, without prior extension');
 requireValue(state.batch_id===run.batch_id&&state.status==='running','Running state mismatch');
 requireValue(!run.commits.stage1&&!run.commits.stage3&&['stage1','stage2','stage3','gate_audit','maintenance'].every(k=>!run.packages[k])&&!run.final_review.sha256,'Reopen downstream packages before advancing framework');
 requireValue(o.reason?.trim()&&o.to===git(root,'rev-parse','HEAD'),'Reason and current committed framework HEAD required');
 const evidence={schema_version:1,batch_id:run.batch_id,business_base:run.base_revision,before_count:run.counts.before,original_checkpoint:checkpointBase(root,runPath),from:o.from,to:o.to,paths:git(root,'diff','--name-only',o.from,o.to).split('\n').filter(Boolean).sort(),reason:o.reason,recorded_at:new Date().toISOString()};
 verifyFrameworkDelta(root,evidence);
 requireValue(git(root,'status','--porcelain','--','system/maintenance/checklists','tests','scripts','release-input','raw-sources/README.md','system/protocols/INGEST_PROTOCOL.md')==='','Framework must be committed before advancing');
 const p=path.posix.dirname(runPath)+'/framework-checkpoint-'+o.to.slice(0,12)+'.json',encoded=encode(evidence);
 fs.writeFileSync(safe(root,p,{exists:false}),encoded,{flag:'wx'});
 requireValue(sha(bytes(root,runPath))===o.runHash,'Concurrent run edit prevents checkpoint update');
 run.raw_standard_checkpoint={path:p,sha256:sha(encoded)};run.updated_at=new Date().toISOString();atomic(root,runPath,encode(run));
 return {status:'framework_checkpoint_advanced',checkpoint_base:checkpointBase(root,runPath),business_base:run.base_revision,before_count:run.counts.before,evidence:p};
}
export function recover(root,runPath){
 root=fs.realpathSync(root);runPath=relative(root,safe(root,runPath));
 const {tx,pointer}=loadTransaction(root,runPath);
 requireValue(tx.status==='prepared','Only an interrupted prepared migration can roll back');
 for(const f of tx.writes){const current=sha(bytes(root,f.path));requireValue([f.before_sha256,f.after_sha256].includes(current),'External edit prevents rollback: '+f.path);requireValue(sha(bytes(root,f.before_path))===f.before_sha256,'Rollback evidence drift');}
 for(const f of tx.writes)atomic(root,f.path,bytes(root,f.before_path));
 tx.status='rolled_back';atomic(root,pointer,encode(tx));
 return {status:'rolled_back',run_path:runPath};
}
export function migrate(root,runPath,options={}){
 root=fs.realpathSync(root);runPath=relative(root,safe(root,runPath));
 const folder=path.posix.dirname(runPath),pointer=folder+'/raw-v2-migration.json';
 requireValue(folder.startsWith('system/maintenance/ingest-runs/')&&path.posix.basename(runPath)==='run.json','Canonical run location required');
 const lock=safe(root,folder+'/.raw-v2-migration.lock',{exists:false});const fd=fs.openSync(lock,'wx');
 try{
  requireValue(!fs.existsSync(safe(root,pointer,{exists:false})),'Migration transaction already exists; inspect/recover it, never overwrite');
  const run=json(root,runPath),state=json(root,statePath);
  requireValue(run.schema_version===7&&run.review_policy==='deferred'&&run.status==='awaiting_final_review'&&!run.managed_task,'Only standalone deferred schema7 awaiting final review is supported');
  requireValue(state.batch_id===run.batch_id&&state.status===run.status&&state.stage==='stage3_completed'&&JSON.stringify(state.items)===JSON.stringify(run.items),'Run/state identity mismatch');
  requireValue(options.producer?.trim()&&options.reason?.trim(),'Actual producer and migration reason required');
  requireValue(options.runHash===sha(bytes(root,runPath))&&options.stateHash===sha(bytes(root,statePath)),'Expected run/state hash mismatch');
  const head=git(root,'rev-parse','HEAD');requireValue(options.baseline===head,'Checkpoint baseline must be current HEAD');
  git(root,'merge-base','--is-ancestor',run.base_revision,head);
  const originals=rawFiles(root,run.base_revision),present=rawFiles(root,head),raws=(run.artifacts??[]).filter(a=>a.kind==='raw'&&a.disposition==='ingested').map(a=>a.path);
  requireValue(originals.length===run.counts.before,'Historical before count mismatch');
  requireValue(new Set(raws).size===raws.length&&raws.every(p=>!originals.includes(p)&&present.includes(p)),'Migrated Raw must be distinct original batch additions');
  requireValue(present.length===originals.length+raws.length,'Current Raw count includes unrelated additions');
  requireValue(git(root,'status','--porcelain','--','Clippings','raw-sources','wiki',folder,statePath,':(exclude)'+folder+'/.raw-v2-migration.lock')==='','Commit corpus and run baseline before migration');
  const dataPath=run.package_data.path;requireValue(dataPath.startsWith(folder+'/'),'Package data must be run local');
  const data=json(root,dataPath);requireValue(data.schema_version===2&&data.batch_id===run.batch_id,'Package identity mismatch');
  const stamp=sha(bytes(root,runPath)).slice(0,16),archive=folder+'/revisions/raw-v2-'+stamp;
  requireValue(!fs.existsSync(safe(root,archive,{exists:false})),'Archive already exists');
  const paths=[...new Set([...walk(root,folder),statePath])].filter(p=>!p.endsWith('/.raw-v2-migration.lock'));
  const snapshots=paths.map(p=>({path:p,archive_path:archive+'/files/'+p,sha256:sha(bytes(root,p))}));
  // Read every source before writing the first archive file.
  const contents=new Map(paths.map(p=>[p,bytes(root,p)]));
  for(const f of snapshots){const dest=safe(root,f.archive_path,{exists:false});fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,contents.get(f.path),{flag:'wx'});}
  fs.writeFileSync(safe(root,archive+'/.gitattributes',{exists:false}),'files/** -text\n',{flag:'wx'});
  const intentPath=archive+'/intent.json';
  const intent={schema_version:1,batch_id:run.batch_id,business_base:run.base_revision,checkpoint_base:head,before_count:run.counts.before,raw_paths:raws,producer:options.producer,reason:options.reason,snapshots};
  fs.writeFileSync(safe(root,intentPath,{exists:false}),encode(intent),{flag:'wx'});
  run.schema_version=8;run.raw_standard='RAW_STANDARD_V2';run.producer_context_id=options.producer;
  run.raw_v2_migration={intent_path:intentPath,transaction_sha256:sha(encode(intent)),checkpoint_base:head};
  run.content_audits=[];run.backtests=[];run.commits={stage1:null,stage3:null};run.counts.after=null;run.counts.required_backtest_anchors=[];
  for(const key of Object.keys(run.packages))run.packages[key]=null;
  for(const key of Object.keys(run.approvals))run.approvals[key]=null;
  for(const key of Object.keys(run.semantic_reviews))run.semantic_reviews[key]={pending:null,active:null,history:[]};
  for(const key of Object.keys(data.sections))data.sections[key]={status:'open',semantic:{summary:'',rows:[],semantic_exceptions:[],unresolved_risks:[],structure_change_requests:[],micro_failures:[]},derived:{},section_sha256:null};
  run.final_review={path:null,sha256:null,approved_sha256:null,content_manifest:null,content_manifest_sha256:null};
  run.status='running_scoring';run.updated_at=new Date().toISOString();state.status='running';state.stage='running_scoring';
  const outputs=new Map([[runPath,encode(run)],[dataPath,encode(data)],[statePath,encode(state)]]);
  const writes=[...outputs].map(([p,b])=>({path:p,before_path:snapshots.find(s=>s.path===p).archive_path,before_sha256:sha(contents.get(p)),after_sha256:sha(b)}));
  const tx={schema_version:1,status:'prepared',run_path:runPath,state_path:statePath,intent_path:intentPath,writes};
  fs.writeFileSync(safe(root,pointer,{exists:false}),encode(tx),{flag:'wx'});
  for(const [i,[p,b]] of [...outputs].entries()){atomic(root,p,b);if(options.failAfterWrite===i+1)throw Error('Injected migration interruption');}
  tx.status='committed';atomic(root,pointer,encode(tx));
  return {status:'migrated',schema_version:8,checkpoint_base:checkpointBase(root,runPath),business_base:run.base_revision,raw_count:raws.length,archive};
 }finally{fs.closeSync(fd);fs.unlinkSync(lock);}
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const [operation,...args]=process.argv.slice(2),o={};for(let i=0;i<args.length;i+=2){requireValue(args[i].startsWith('--')&&args[i+1],'Expected option value');o[args[i].slice(2)]=args[i+1];}
 const root=o.root??path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
 const result=operation==='migrate'?migrate(root,o.run,{producer:o.producer,reason:o.reason,runHash:o['run-hash'],stateHash:o['state-hash'],baseline:o.baseline}):operation==='advance-checkpoint'?advanceCheckpoint(root,o.run,{from:o.from,to:o.to,runHash:o['run-hash'],reason:o.reason}):operation==='recover'?recover(root,o.run):operation==='checkpoint-base'?checkpointBase(root,o.run):(()=>{throw Error('Use migrate, recover, checkpoint-base or advance-checkpoint');})();
 console.log(typeof result==='string'?result:JSON.stringify(result,null,2));
 }catch(e){console.error(e.message);process.exitCode=1;}
}
