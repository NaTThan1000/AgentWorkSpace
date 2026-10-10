#!/usr/bin/env node
// Godot project-local delivery. No network, package execution or engine mutations.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
export const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const json = x => Buffer.from(JSON.stringify(x,null,2)+'\n');
const fail = s => { throw Error(s); };
export function safe(root, rel='') {
 if(typeof rel!=='string'||path.isAbsolute(rel)||rel.includes('\\')||rel.includes(':')||rel.split('/').some(p=>p==='..'||p==='.') ) fail('unsafe path: '+rel);
 const base=path.resolve(root), out=path.resolve(base,rel);
 if(out!==base&&!out.startsWith(base+path.sep))fail('path escapes root');
 // Reject links in every existing ancestor, including root ancestors.
 let cur=path.parse(out).root;
 for(const p of out.slice(cur.length).split(path.sep).filter(Boolean)){
  cur=path.join(cur,p);
  try { if(fs.lstatSync(cur).isSymbolicLink())fail('symbolic link: '+cur); }
  catch(e) { if(e.code!=='ENOENT'&&e.code!=='ENOTDIR')throw e; }
 }
 return out;
}
const read = p => fs.readFileSync(p);
const parse = p => JSON.parse(read(p));
function current(p){return fs.existsSync(p)?read(p).toString('base64'):null;}
function atomic(p, bytes){
 fs.mkdirSync(path.dirname(p),{recursive:true});
 const temp=p+'.tmp-'+crypto.randomUUID();
 fs.writeFileSync(temp,bytes,{flag:'wx'});
 fs.renameSync(temp,p);
}
function context(engine,bundle){
 if(!/^[a-z][a-z0-9-]{0,47}$/.test(bundle))fail('invalid bundle');
 engine=safe(engine);
 if(!fs.existsSync(safe(engine,'project.godot')))fail('missing project.godot');
 const project=path.dirname(engine), config=parse(safe(project,'maintenance/project-config.json'));
 if(config.engine.directory!==path.basename(engine))fail('engine does not match project config');
 const dest=safe(engine,'assets/vendor/'+bundle), history=safe(project,'maintenance/asset-deliveries/'+bundle);
 return {engine,project,dest,history,bundle};
}
function checkFiles(c, receipt) {
 if(receipt?.contract!==(c.contract??'gamepresentation-godot-v1')||receipt.bundle!==c.bundle)fail('invalid ownership receipt');
 for(const [rel,h] of Object.entries(receipt.files)){
  const p=safe(c.dest,rel);
  if(!fs.existsSync(p)||sha(read(p))!==h)fail('owned file modified or missing: '+rel);
 }
}
export function receipt(c){
 const p=safe(c.dest,'receipt.json');
 if(!fs.existsSync(p)) {
  if(fs.existsSync(c.dest)&&fs.readdirSync(c.dest).length)fail('unowned destination');
  return null;
 }
 const r=parse(p);checkFiles(c,r);return r;
}
export function desired(source, ids){
 source=safe(source);
 if(!Array.isArray(ids)||!ids.length||new Set(ids).size!==ids.length)fail('empty or duplicate IDs');
 const catalog=parse(safe(source,'catalog/assets.json'));
 const sources=parse(safe(source,'catalog/sources.json')).sources;
 const formalPath=safe(source,'catalog/formal-assets.json');
 if(fs.existsSync(formalPath)){
  const formal=parse(formalPath);
  if(formal.schema_version!==1||!Array.isArray(formal.assets))fail('invalid formal catalog');
  for(const a of formal.assets){
   if(!Array.isArray(a.consumers)||!a.consumers.includes('godot'))fail('formal asset not approved for Godot');
  }
  catalog.assets.push(...formal.assets);
  sources.push(...parse(safe(source,'catalog/formal-sources.json')).sources);
 }
 const all=new Map();
 for(const a of catalog.assets){if(all.has(a.asset_id))fail('duplicate catalog ID');all.set(a.asset_id,a);}
 const files={}, selected=[];
 function add(rel,bytes){if(files[rel]&&files[rel]!==bytes.toString('base64'))fail('output collision');files[rel]=bytes.toString('base64');}
 for(const id of [...ids].sort()){
  const a=all.get(id);if(!a)fail('unknown ID: '+id);
  if(a.public_release_allowed!==true)fail('asset not approved: '+id);
  if(!['CC0-1.0','MIT','OFL-1.1','Apache-2.0','BSD-2-Clause','BSD-3-Clause'].includes(a.license.spdx))fail('unsupported license');
  const rp=safe(source,a.license.receipt_path), r=parse(rp);
  if(r.public_release_allowed!==true||r.license_spdx!==a.license.spdx||r.source_url!==a.source.url)fail('receipt approval mismatch');
  if(!sources.some(s=>s.source_url===a.source.url&&s.license_spdx===a.license.spdx&&s.public_release_allowed===true&&s.receipt_path===a.license.receipt_path))fail('unregistered source');
  if(!r.evidence_paths?.length)fail('missing license evidence');
  const evidence=[];
  for(const e of [a.license.receipt_path,...r.evidence_paths]){
   const bytes=read(safe(source,e));
   if(!bytes.length)fail('empty license evidence');
   const name='licenses/'+sha(bytes).slice(0,16)+'-'+path.basename(e);
   add(name,bytes);evidence.push(name);
  }
  if(typeof a.normalized_path!=='string'||!a.normalized_path)fail('missing normalized path');
  const bytes=read(safe(source,a.normalized_path));
  if(sha(bytes)!==a.files.normalized_sha256)fail('source hash mismatch');
  const ext=path.extname(a.normalized_path).toLowerCase();
  if(!['.png','.wav','.ogg','.ttf','.otf'].includes(ext))fail('unsupported asset format');
  const target='media/'+id.replace(/[^a-zA-Z0-9_-]/g,'-')+'-'+sha(Buffer.from(id)).slice(0,8)+ext;
  add(target,bytes);
  selected.push({asset_id:id,source:a.source,license:a.license.spdx,evidence,original_sha256:a.files.original_sha256,
   normalized_sha256:a.files.normalized_sha256,delivered_sha256:sha(bytes),path:target,
   processing:[...(a.processing??[]),{operation:'copy-normalized',input:a.normalized_path}],verification:'hash-and-source-receipt; engine validation separate'});
 }
 add('.gitattributes',Buffer.from('# Preserve receipt-owned bytes despite parent Godot text=auto defaults.\n* -text\nlicenses/** -whitespace\n'));
 add('README.md',Buffer.from('# Imported asset bundle\n\n## 目录\n- [media/](media/README.md)：精选素材。\n- [licenses/](licenses/README.md)：来源与许可证据。\n\nreceipt.json owns files; update through GamePresentation. No runtime dependency on the source repository.\n'));
 for(const d of ['media','licenses'])add(d+'/README.md',Buffer.from('# '+d+'\n\n## 目录\n无下级目录。\n\nOwned by the asset delivery receipt. Do not edit imported files in place.\n'));
 return {files,selected};
}
export function plan(c, old, next, selected, previous=null){
 const hashes=Object.fromEntries(Object.entries(next).map(([p,b])=>[p,sha(Buffer.from(b,'base64'))]));
 if(old&&JSON.stringify(old.files)===JSON.stringify(hashes)&&JSON.stringify(old.assets)===JSON.stringify(selected))return {noop:true,changes:[]};
 const batch=crypto.randomUUID();
 const after={...next,'receipt.json':json({contract:c.contract??'gamepresentation-godot-v1',bundle:c.bundle,batch,previous_batch:previous??old?.batch??null,assets:selected,files:hashes}).toString('base64')};
 const before={};
 for(const rel of new Set([...Object.keys(old?.files??{}),...Object.keys(after),'receipt.json'])){
  const p=safe(c.dest,rel);before[rel]=current(p);
  if(!(rel in after))after[rel]=null;
  if(before[rel]!==null&&rel!=='receipt.json'&&!(rel in (old?.files??{})))fail('unowned file collision: '+rel);
 }
 const changes=Object.keys(after).filter(p=>before[p]!==after[p]).map(p=>({path:p,action:before[p]===null?'add':after[p]===null?'remove':'replace'}));
 return {contract:'gamepresentation-transaction-v1',bundle:c.bundle,batch,before,after,changes};
}
function lock(c){
 fs.mkdirSync(c.history,{recursive:true});
 const p=safe(c.history,'lock.json');
 const fd=fs.openSync(p,'wx');fs.writeFileSync(fd,json({pid:process.pid}));fs.closeSync(fd);
 return ()=>fs.unlinkSync(p);
}
function verifyTransaction(c,t){
 if(t.contract!=='gamepresentation-transaction-v1'||t.bundle!==c.bundle||!/^[0-9a-f-]{36}$/.test(t.batch))fail('invalid transaction');
 if(JSON.stringify(Object.keys(t.before).sort())!==JSON.stringify(Object.keys(t.after).sort()))fail('transaction path mismatch');
 for(const rel of Object.keys(t.before))safe(c.dest,rel);
}
export function pending(c){return safe(c.history,'pending.json');}
export function perform(c,t,{apply=false,failAfter=-1}={}){
 if(t.noop||!apply)return {applied:false,noop:!!t.noop,changes:t.changes,batch:t.batch};
 const unlock=lock(c);
 let journal=false;
 try{
  if(fs.existsSync(pending(c)))fail('pending transaction: recover first');
  for(const [rel,b] of Object.entries(t.before))if(current(safe(c.dest,rel))!==b)fail('destination changed after plan');
  atomic(pending(c),json(t));journal=true;
  let writes=0;
  // Receipt last. Each source-owned deletion is recoverable from durable journal.
  for(const rel of [...Object.keys(t.after).filter(p=>p!=='receipt.json'),'receipt.json']){
   if(t.after[rel]===t.before[rel])continue;
   if(writes++===failAfter)fail('injected interruption');
   const p=safe(c.dest,rel), b=t.after[rel];
   if(b===null){if(fs.existsSync(p))fs.unlinkSync(p);}
   else atomic(p,Buffer.from(b,'base64'));
  }
  atomic(safe(c.history,t.batch+'.json'),json(t));
  fs.unlinkSync(pending(c));journal=false;
  return {applied:true,noop:false,changes:t.changes,batch:t.batch};
 }catch(e){throw Error(e.message+(journal?'; durable journal retained, use recover':''));}
 finally{unlock();}
}
export function deliver({source,engine,bundle,ids,apply=false,failAfter=-1}){
 const c=context(engine,bundle);
 if(fs.existsSync(pending(c)))fail('pending transaction: recover first');
 const old=receipt(c), d=desired(source,ids);
 return perform(c,plan(c,old,d.files,d.selected),{apply,failAfter});
}
export function rollback({engine,bundle,apply=false}){ return rollbackContext(context(engine,bundle),{apply}); }
export function rollbackContext(c,{apply=false}={}){
 if(fs.existsSync(pending(c)))fail('pending transaction: recover first');
 const old=receipt(c);if(!old)fail('nothing to rollback');
 const t=parse(safe(c.history,old.batch+'.json'));verifyTransaction(c,t);
 if(t.after['receipt.json']!==current(safe(c.dest,'receipt.json')))fail('receipt differs from recorded transaction');
 // Roll back one recorded delivery as another transaction, preserve complete history.
 const next={};
 for(const [rel,b] of Object.entries(t.before))if(rel!=='receipt.json'&&b!==null)next[rel]=b;
 const prior=t.before['receipt.json']?JSON.parse(Buffer.from(t.before['receipt.json'],'base64')):null;
 if(!prior)for(const rel of ['README.md','media/README.md','licenses/README.md'])if(t.after[rel])next[rel]=t.after[rel];
 return perform(c,plan(c,old,next,prior?.assets??[],old.batch),{apply});
}
export function recover({engine,bundle,apply=false}){ return recoverContext(context(engine,bundle),{apply}); }
export function recoverContext(c,{apply=false}={}){
 const p=pending(c);
 if(!fs.existsSync(p))return {noop:true,applied:false};
 const t=parse(p);verifyTransaction(c,t);
 const lp=safe(c.history,'lock.json');
 if(fs.existsSync(lp)){
  const pid=parse(lp).pid;
  try{process.kill(pid,0);fail('transaction process still alive');}
  catch(e){if(e.code!=='ESRCH')throw e;}
  if(!apply)return {applied:false,changes:t.changes,stale_lock:true};
  fs.unlinkSync(lp);
 }
 for(const rel of Object.keys(t.before)){
  const b=current(safe(c.dest,rel));
  if(b!==t.before[rel]&&b!==t.after[rel])fail('recovery conflict: '+rel);
 }
 if(!apply)return {applied:false,changes:t.changes};
 const unlock=lock(c);
 try{
  for(const rel of [...Object.keys(t.before).filter(p=>p!=='receipt.json'),'receipt.json']){
   const p=safe(c.dest,rel), b=t.before[rel];
   if(b===null){if(fs.existsSync(p))fs.unlinkSync(p);}
   else atomic(p,Buffer.from(b,'base64'));
  }
  // First-delivery recovery must also remove newly-created, now-empty leaf directories.
  // Only derive candidates from reverted new files; never recursively remove a tree.
  const emptyCandidates=new Set();
  for(const [rel,b] of Object.entries(t.before))if(b===null){
   let dir=path.dirname(safe(c.dest,rel));
   while(dir!==c.dest&&dir.startsWith(c.dest+path.sep)){emptyCandidates.add(dir);dir=path.dirname(dir);}
  }
  for(const dir of [...emptyCandidates].sort((a,b)=>b.length-a.length)){
   safe(c.dest,path.relative(c.dest,dir).split(path.sep).join('/'));
   if(fs.existsSync(dir)&&fs.readdirSync(dir).length===0)fs.rmdirSync(dir);
  }
  atomic(safe(c.history,t.batch+'-recovered.json'),json(t));
  fs.unlinkSync(pending(c));
 }finally{unlock();}
 return {applied:true,recovered:t.batch};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const args=process.argv.slice(2), action=args.shift()??'import', opts={ids:[]};
  while(args.length){
   const k=args.shift();
   if(k==='--apply')opts.apply=true;
   else if(k==='--id')opts.ids.push(args.shift());
   else if(['--source','--engine','--bundle'].includes(k))opts[k.slice(2)]=args.shift();
   else fail('unknown option '+k);
  }
  if(!opts.engine||!opts.bundle)fail('required: --engine PATH --bundle NAME');
  const fn={import:deliver,rollback,recover}[action];if(!fn)fail('unknown action');
  console.log(JSON.stringify(fn(opts),null,2));
 }catch(e){console.error(e.message);process.exitCode=1;}
}
