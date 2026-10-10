#!/usr/bin/env node
// Two-hop local delivery. Shared writes/ownership/recovery live in deliver.mjs.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {safe,sha,desired,receipt,plan,pending,perform,rollbackContext,recoverContext} from './deliver.mjs';

const read=p=>fs.readFileSync(p), parse=p=>JSON.parse(read(p));
const bytes=o=>Buffer.from(JSON.stringify(o,null,2)+'\n');
const hashes=files=>Object.fromEntries(Object.entries(files).map(([p,b])=>[p,sha(Buffer.from(b,'base64'))]));
const fail=s=>{throw Error(s);};
function name(v){if(typeof v!=='string'||!/^[a-z][a-z0-9-]{0,47}$/.test(v))fail('invalid bundle/revision');return v;}
function rel(v){if(typeof v!=='string'||!v||v.split('/').some(x=>!x))fail('empty relative path');return v;}
export function projectContext(project){
 project=safe(project);
 const config=parse(safe(project,'maintenance/project-config.json'));
 const source=safe(project,rel(config.assets?.directory)),engine=safe(project,rel(config.engine?.directory));
 const a=source.toLowerCase(),b=engine.toLowerCase();
 if(a===b||a.startsWith(b+path.sep)||b.startsWith(a+path.sep))fail('assets/engine overlap');
 if(config.assets.contract_version!==1)fail('unsupported workbench contract');
 const catalog=parse(safe(source,'catalog.json'));
 if(catalog.schema_version!==1||!Array.isArray(catalog.assets))fail('invalid catalog');
 const all=new Map();
 for(const a of catalog.assets){if(all.has(a.id))fail('duplicate project ID');all.set(a.id,a);}
 return {project,config,source,engine,all};
}
export function deliveryContext(project,bundle,revision,phase){
 const p=projectContext(project);name(bundle);
 if(!['receive','receive-generated','seal','publish'].includes(phase))fail('invalid phase');
 if(phase!=='publish')name(revision);
 const suffix=phase==='publish'?bundle:bundle+'-'+revision;
 const dest=phase==='receive'?safe(p.source,'sources/vendor/'+bundle+'/'+revision):phase==='receive-generated'?safe(p.source,'sources/generated/'+bundle+'/'+revision):phase==='seal'?safe(p.source,'releases/'+bundle+'/'+revision):safe(p.engine,'assets/project/'+bundle);
 const history=safe(p.project,'maintenance/asset-deliveries/workbench-'+phase+'-'+suffix);
 if(phase==='publish'&&!fs.existsSync(safe(p.engine,'project.godot')))fail('missing configured project.godot');
 return {...p,dest,history,bundle:suffix,contract:phase==='publish'?'gamepresentation-project-install-v1':'gamepresentation-workbench-owned-v1'};
}
function select(p,ids){
 if(!Array.isArray(ids)||!ids.length||new Set(ids).size!==ids.length)fail('empty or duplicate IDs');
 return [...ids].sort().map(id=>{const a=p.all.get(id);if(!a)fail('unknown project ID: '+id);return a;});
}
function checked(project,p,hash){const f=safe(project,rel(p)),b=read(f);if(sha(b)!==hash)fail('hash mismatch: '+p);return b;}
function snapshot(p,a){
 if(!a.source?.receipt?.startsWith(p.config.assets.directory+'/sources/'))fail('missing source snapshot');
 const file=safe(p.project,a.source.receipt), r=parse(file),base=path.dirname(file);
 if(r.contract!=='source-snapshot-v1'||!r.origin||!Object.keys(r.files??{}).length)fail('invalid snapshot');
 for(const [f,h] of Object.entries(r.files))if(sha(read(safe(base,rel(f))))!==h)fail('snapshot hash mismatch: '+f);
 for(const f of a.source.files??[]){
  const absolute=safe(p.project,rel(f.path));
  const relative=path.relative(base,absolute).replaceAll('\\','/');safe(base,relative);
  if(r.files[relative]!==f.sha256)fail('source not owned by snapshot');checked(p.project,f.path,f.sha256);
 }
 return {r,base,file};
}
function immutable(c,files,selected,options){
 if(fs.existsSync(pending(c)))fail('pending transaction: recover first');
 const old=receipt(c),t=plan(c,old,files,selected);
 if(old&&!t.noop)fail('immutable version: select a new revision');
 return {...perform(c,t,options),destination:c.dest};
}
export function receive({project,source,bundle,revision,ids,apply=false,failAfter=-1}){
 const c=deliveryContext(project,bundle,revision,'receive'),items=select(c,ids);
 const upstream=[...new Set(items.map(a=>a.source?.upstream_id??a.id))],d=desired(source,upstream);
 const sourceAssets=d.selected.flatMap(a=>items.filter(x=>(x.source?.upstream_id??x.id)===a.asset_id).map(x=>({...a,project_id:x.id})));
 const s={contract:'source-snapshot-v1',origin:{kind:'PrototypeAssets',bundle,revision},assets:sourceAssets,files:hashes(d.files)};
 d.files['snapshot.json']=bytes(s).toString('base64');
 // No automatic catalog overwrite: explicit source binding is a project maintenance decision.
 const result=immutable(c,d.files,sourceAssets,{apply,failAfter});
 return {...result,bindings:sourceAssets.map(a=>({id:a.project_id,source:{kind:'vendor',upstream_id:a.asset_id,version:revision,receipt:path.relative(c.project,path.join(c.dest,'snapshot.json')).replaceAll('\\','/'),files:[{path:path.relative(c.project,path.join(c.dest,a.path)).replaceAll('\\','/'),sha256:a.delivered_sha256}]}}))};
}
export function receiveGenerated({project,source,bundle,revision,ids,apply=false,failAfter=-1}){
 const c=deliveryContext(project,bundle,revision,'receive-generated'),items=select(c,ids),manifest=parse(safe(source,'generation.json'));
 if(manifest.kind!=='generated'||!Array.isArray(manifest.assets))fail('invalid generated manifest');
 const files={},selected=[],records=[];
 for(const a of items){
  const m=manifest.assets.find(x=>x.id===a.id);
  if(!m||!m.producer||typeof m.version!=='string'||!m.prompt||!m.file||!Array.isArray(m.references))fail('incomplete generated provenance');
  const b=read(safe(source,rel(m.file.path)));if(sha(b)!==m.file.sha256)fail('generated source hash mismatch');
  if(path.extname(m.file.path).toLowerCase()!=='.png')fail('generated receiver currently supports PNG');
  const target='media/'+a.id.replace(/[^a-z0-9_-]/g,'-')+'-'+sha(Buffer.from(a.id)).slice(0,8)+'.png';
  files[target]=b.toString('base64');records.push(m);selected.push({asset_id:a.id,path:target,delivered_sha256:sha(b)});
 }
 files['generation.json']=bytes({kind:'generated',assets:records}).toString('base64');
 files['.gitattributes']=Buffer.from('* -text\n').toString('base64');
 files['README.md']=Buffer.from('# Generated source snapshot\n\n## 目录\n- [media/](media/README.md)\n\nFull generation record is internal. No rights approval is implied.\n').toString('base64');
 files['media/README.md']=Buffer.from('# Raw generated media\n\n## 目录\n无下级目录。\n').toString('base64');
 files['snapshot.json']=bytes({contract:'source-snapshot-v1',origin:{kind:'generated',bundle,revision},assets:selected,files:hashes(files)}).toString('base64');
 return {...immutable(c,files,selected,{apply,failAfter}),bindings:selected.map(a=>({id:a.asset_id,source:{kind:'generated',version:revision,receipt:path.relative(c.project,path.join(c.dest,'snapshot.json')).replaceAll('\\','/'),files:[{path:path.relative(c.project,path.join(c.dest,a.path)).replaceAll('\\','/'),sha256:a.delivered_sha256}]}}))};
}
function gateEvidence(p,a){
 if(a.stage!=='ready')fail('asset not ready: '+a.id);
 if(!a.spec?.startsWith(p.config.assets.directory+'/specs/'))fail('invalid spec');
 const spec=read(safe(p.project,a.spec));
 const evidence={};
 for(const key of ['concept','purpose','technical','rights']){
  const g=a.gates?.[key];
  if(g?.status!=='pass'||!g.evidence?.length)fail('gate not passed: '+key+' '+a.id);
  for(const e of g.evidence){const b=read(safe(p.project,rel(e)));if(!b.length)fail('empty gate evidence');evidence[e]=sha(b);}
 }
 return {spec_sha256:sha(spec),evidence};
}
function releaseDesired(c,ids,bundle,revision){
 const files={},assets=[],bindings=[];
 const add=(p,b)=>{safe(c.dest,rel(p));const value=b.toString('base64');if(files[p]&&files[p]!==value)fail('output collision');files[p]=value;};
 for(const a of select(c,ids)){
  const gates=gateEvidence(c,a),s=snapshot(c,a);
  if(!['vendor','generated','custom'].includes(a.source.kind))fail('unsupported release source');
  if(a.source.kind==='vendor'&&!['PrototypeAssets','existing-engine-receipt'].includes(s.r.origin.kind))fail('vendor source kind mismatch');
  if(a.source.kind!=='vendor'&&s.r.origin.kind!==a.source.kind)fail('source kind mismatch');
  const input=a.delivery?.file??a.source.files?.[0];
  if(!input)fail('missing delivery input');
  if(!input.path.startsWith(c.config.assets.directory+'/sources/')&&!input.path.startsWith(c.config.assets.directory+'/work/'))fail('delivery input outside workbench');
  const b=checked(c.project,input.path,input.sha256),ext=path.extname(input.path).toLowerCase();
  if(!['.png','.wav','.ogg','.ttf','.otf'].includes(ext))fail('unsupported media format');
  if(a.delivery?.file&&(!a.delivery.processing?.length||!a.source.files?.length))fail('processed asset needs source and recipe');
  const target='media/'+a.id.replace(/[^a-zA-Z0-9_-]/g,'-')+'-'+sha(Buffer.from(a.id)).slice(0,8)+ext;
  add(target,b);
  let provenance,license,licenseFiles=[];
  if(a.source.kind==='vendor'){
   const original=s.r.assets??parse(safe(s.base,'receipt.json')).assets;
   const v=original.find(x=>x.asset_id===a.source.upstream_id);
   if(!v||!['CC0-1.0','MIT','OFL-1.1','Apache-2.0','BSD-2-Clause','BSD-3-Clause'].includes(v.license))fail('unsupported vendor provenance');
   if(!a.source.files.some(f=>f.sha256===v.delivered_sha256))fail('vendor source binding mismatch');
   // Audit HTML stays internal. Keep actual license text; receipts remain internal proof.
   let approved=false;
   for(const f of v.evidence??[]){
    const data=read(safe(s.base,rel(f)));if(s.r.files[f]!==sha(data))fail('license not owned by snapshot');
    if(f.endsWith('.json')){const r=JSON.parse(data);if(r.public_release_allowed===true&&r.license_spdx===v.license&&r.source_url===v.source.url)approved=true;}
    if(/\.(txt|md)$/i.test(f)){const target='licenses/'+sha(data).slice(0,16)+'-'+path.basename(f);add(target,data);licenseFiles.push(target);}
   }
   if(!approved||!licenseFiles.length)fail('vendor license approval/text missing');
   license=v.license;provenance={kind:'vendor',asset_id:v.asset_id,source_url:v.source.url,source_sha256:v.delivered_sha256};
  }else{
   // Project-owned rights record is explicit, never inferred from the image generator or a tool license.
   const rights=a.delivery?.rights;
   if(rights?.distribution_allowed!==true||!rights.basis||!rights.evidence?.length)fail('generated/custom distribution rights unresolved');
   for(const e of rights.evidence){const data=read(safe(c.project,rel(e)));if(!data.length)fail('empty rights evidence');gates.evidence[e]=sha(data);}
   for(const f of a.delivery?.licenses??[]){const data=checked(c.project,f.path,f.sha256);if(!/\.(txt|md)$/i.test(f.path))fail('unsupported public notice');const target='licenses/'+sha(data).slice(0,16)+'-'+path.basename(f.path);add(target,data);licenseFiles.push(target);}
   license='project-rights-reviewed';provenance={kind:a.source.kind,source_sha256:a.source.files.map(f=>f.sha256)};
  }
  const consumer=a.delivery?.consumer??{};
  if(Object.keys(consumer).some(k=>!['filter','anchor','display_size','mipmaps'].includes(k)))fail('unsupported consumer field');
  if(consumer.filter!==undefined&&!['linear','nearest','linear-mipmap'].includes(consumer.filter))fail('invalid consumer filter');
  if(consumer.mipmaps!==undefined&&typeof consumer.mipmaps!=='boolean')fail('invalid mipmaps flag');
  for(const k of ['anchor','display_size'])if(consumer[k]!==undefined&&(!Array.isArray(consumer[k])||consumer[k].length!==2||consumer[k].some(n=>!Number.isFinite(n)||n<0||(k==='anchor'&&n>1))))fail('invalid consumer geometry');
  const processing=(a.delivery?.processing??[{operation:'copy-source'}]).map(p=>{
   if(!/^[a-z][a-z-]{0,39}$/.test(p.operation??''))fail('invalid processing operation');
   return {operation:p.operation}; // Full private recipe remains in internal bindings, not the runtime receipt.
  });
  assets.push({asset_id:a.id,purpose:a.purpose,path:target,delivered_sha256:sha(b),license,evidence:licenseFiles,source:provenance,consumer,processing});
  bindings.push({id:a.id,source:a.source,input,gate_evidence:gates,delivery:a.delivery??null,purpose:a.purpose,spec:a.spec});
 }
 add('.gitattributes',Buffer.from('* -text\n'));
 add('README.md',Buffer.from('# Project runtime bundle\n\n## 目录\n- [media/](media/README.md)\n- [licenses/](licenses/README.md)\n\nSelected runtime data only; full sources and prompts stay in the workbench.\n'));
 for(const d of ['media','licenses'])add(d+'/README.md',Buffer.from('# '+d+'\n\n## 目录\n无下级目录。\n'));
 return {files,assets,release:{contract:'gamepresentation-release-v1',bundle,revision,assets,bindings,files:hashes(files)}};
}
export function seal({project,bundle,revision,ids,apply=false,failAfter=-1}){
 const c=deliveryContext(project,bundle,revision,'seal'),d=releaseDesired(c,ids,bundle,revision);
 d.files['release.json']=bytes(d.release).toString('base64');
 return {...immutable(c,d.files,d.assets,{apply,failAfter}),release:path.relative(c.project,path.join(c.dest,'release.json')).replaceAll('\\','/')};
}
function verifyRelease(c,bundle,revision){
 name(revision);
 const dir=safe(c.source,'releases/'+bundle+'/'+revision),file=safe(dir,'release.json'),r=parse(file);
 if(r.contract!=='gamepresentation-release-v1'||r.bundle!==bundle||r.revision!==revision||!r.assets?.length)fail('invalid release');
 const owned=deliveryContext(c.project,bundle,revision,'seal');receipt(owned);
 if(fs.existsSync(pending(owned)))fail('pending release transaction');
 // Recompile against current project decision/source bindings. A stale gate/spec/source invalidates release.
 const d=releaseDesired(owned,r.assets.map(a=>a.asset_id),bundle,revision);
 if(JSON.stringify(d.release)!==JSON.stringify(r))fail('stale release: project source/spec/gates changed');
 const relative=path.relative(c.project,file).replaceAll('\\','/');
 for(const a of r.assets)if(c.all.get(a.asset_id).desired_release!==relative)fail('desired release mismatch: '+a.asset_id);
 const files={};for(const [p,h] of Object.entries(r.files)){const b=read(safe(dir,rel(p)));if(sha(b)!==h)fail('release hash mismatch');files[p]=b.toString('base64');}
 // Only a sanitized runtime provenance goes into the engine. No bindings, prompt, private evidence or internal source paths.
 const publicAssets=r.assets.map(a=>({...a,release:{bundle,revision,sha256:sha(read(file))}}));
 return {files,assets:publicAssets};
}
export function publish({project,bundle,revision,apply=false,failAfter=-1}){
 const c=deliveryContext(project,bundle,revision,'publish');
 const contract=c.config.assets.workflow_contract;
 if(!contract||!fs.existsSync(path.resolve(c.project,contract)))fail('workflow contract unavailable');
 if(fs.existsSync(pending(c)))fail('pending transaction: recover first');
 const d=verifyRelease(c,bundle,revision),old=receipt(c);
 return {...perform(c,plan(c,old,d.files,d.assets),{apply,failAfter}),destination:c.dest};
}
export function rollback({project,bundle,apply=false}){return rollbackContext(deliveryContext(project,bundle,null,'publish'),{apply});}
export function recover({project,bundle,revision,phase='publish',apply=false}){return recoverContext(deliveryContext(project,bundle,revision,phase),{apply});}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const argv=process.argv.slice(2),action=argv.shift(),options={ids:[]};
  while(argv.length){const k=argv.shift();if(k==='--apply')options.apply=true;else if(k==='--id')options.ids.push(argv.shift());else if(['--project','--source','--bundle','--revision','--phase'].includes(k))options[k.slice(2)]=argv.shift();else fail('unknown option: '+k);}
  if(!options.project||!options.bundle)fail('required: --project --bundle');
  const fn={receive,'receive-generated':receiveGenerated,seal,publish,rollback,recover}[action];if(!fn)fail('unknown action');console.log(JSON.stringify(fn(options),null,2));
 }catch(e){console.error(e.message);process.exitCode=1;}
}
