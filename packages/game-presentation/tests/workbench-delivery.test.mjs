import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {receive,receiveGenerated,seal,publish,rollback,recover,deliveryContext} from '../adapters/godot/workbench.mjs';
import {sha} from '../adapters/godot/deliver.mjs';
import {checkAssets} from '../project-tools/check-assets.mjs';

export function fixture(t){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'gp-two-hop-'));
 t.after(()=>{assert.ok(root.startsWith(path.join(os.tmpdir(),'gp-two-hop-')));fs.rmSync(root,{recursive:true,force:true});});
 const project=path.join(root,'project'),source=path.join(root,'upstream');
 const put=(p,b)=>{const f=path.join(root,p);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,typeof b==='object'&&!Buffer.isBuffer(b)?JSON.stringify(b):b);};
 put('project/Engine/project.godot','config_version=5');put('project/contract.md','Fixture contract, not a real approval.');
 const config={engine:{directory:'Engine'},assets:{directory:'assets',contract_version:1,workflow_contract:'contract.md'}};
 put('project/maintenance/project-config.json',config);put('project/assets/specs/one.md','Synthetic purpose spec.');put('project/assets/work/approval.md','Synthetic approval for test bytes only, not a real product decision.');
 const a={id:'hero.board',object_id:'hero',owner:'fixture',priority:'P0',references:[],work_path:null,consumers:[],purpose:'board',stage:'planned',spec:'assets/specs/one.md',source:{kind:'planned',version:'none',upstream_id:'test:one',files:[]},desired_release:null,gates:Object.fromEntries(['concept','purpose','technical','rights'].map(k=>[k,{status:'pending',evidence:[]}]))};
 const catalog={schema_version:1,assets:[a]}, save=()=>put('project/assets/catalog.json',catalog);save();
 const meta={asset_id:'test:one',source:{url:'https://fixture.invalid/pack'},license:{spdx:'CC0-1.0',receipt_path:'license/receipt.json'},public_release_allowed:true,normalized_path:'normalized/one.png',files:{original_sha256:sha(Buffer.from('one')),normalized_sha256:sha(Buffer.from('one'))}};
 put('upstream/normalized/one.png','one');put('upstream/license/LICENSE.txt','Fixture license text, not real media.');put('upstream/license/page.html','Private audit page');
 put('upstream/license/receipt.json',{public_release_allowed:true,license_spdx:'CC0-1.0',source_url:meta.source.url,evidence_paths:['license/LICENSE.txt','license/page.html']});
 const saveUpstream=()=>put('upstream/catalog/assets.json',{assets:[meta]});saveUpstream();put('upstream/catalog/sources.json',{sources:[{source_url:meta.source.url,license_spdx:'CC0-1.0',receipt_path:'license/receipt.json',public_release_allowed:true}]});
 const options={project,source,bundle:'test',revision:'v1',ids:[a.id]};
 const acquire=(revision='v1')=>{const r=receive({...options,revision,apply:true});a.source=r.bindings[0].source;a.stage='acquired';save();return r;};
 const approve=()=>{a.stage='ready';for(const g of Object.values(a.gates)){g.status='pass';g.evidence=['assets/work/approval.md'];}save();};
 const release=(revision='v1')=>{const r=seal({...options,revision,apply:true});a.desired_release=r.release;save();return r;};
 const install=(revision='v1')=>publish({...options,revision,apply:true});
 const installed=()=>{const c=deliveryContext(project,'test',null,'publish'),r=JSON.parse(fs.readFileSync(path.join(c.dest,'receipt.json')));return {c,r,file:path.join(c.dest,r.assets[0]?.path??'none')};};
 return {root,project,source,put,a,catalog,config,save,meta,saveUpstream,options,acquire,approve,release,install,installed};
}
test('receive dry run writes nothing; apply preserves provenance, replay is no-op',t=>{
 const f=fixture(t),plan=receive(f.options);assert.equal(plan.applied,false);assert.equal(fs.existsSync(plan.destination),false);
 const r=f.acquire();assert.equal(r.applied,true);assert.equal(receive(f.options).noop,true);assert.ok(fs.existsSync(path.join(r.destination,'snapshot.json')));
 assert.equal(fs.existsSync(path.join(f.project,'Engine/assets')),false);
});
test('source revision is immutable, explicit new revision leaves previous bytes',t=>{
 const f=fixture(t),r=f.acquire();f.meta.files.normalized_sha256=sha(Buffer.from('two'));f.put('upstream/normalized/one.png','two');f.saveUpstream();
 assert.throws(()=>receive({...f.options,apply:true}),/immutable/);const next=f.acquire('v2');assert.notEqual(r.destination,next.destination);
 assert.equal(fs.readFileSync(path.join(r.destination,JSON.parse(fs.readFileSync(path.join(r.destination,'receipt.json'))).assets[0].path),'utf8'),'one');
});
test('one upstream asset can serve separate project purpose IDs without duplicated source bytes',t=>{
 const f=fixture(t);f.catalog.assets.push({...structuredClone(f.a),id:'hero.icon',purpose:'icon'});f.save();
 const r=receive({...f.options,ids:['hero.board','hero.icon'],apply:true});assert.equal(r.bindings.length,2);assert.equal(r.bindings[0].source.files[0].path,r.bindings[1].source.files[0].path);
});
test('unapproved purpose and rights cannot seal; merely received is not adopted',t=>{
 const f=fixture(t);f.acquire();assert.throws(()=>seal(f.options),/not ready/);f.approve();f.a.gates.rights.status='pending';f.save();assert.throws(()=>seal(f.options),/gate not passed/);
});
test('seal/publish dry-run, no-op, and disconnected engine only has runtime files/not private audit',t=>{
 const f=fixture(t);f.acquire();f.approve();const p=seal(f.options);assert.equal(fs.existsSync(p.destination),false);f.release();
 assert.equal(seal(f.options).noop,true);assert.equal(publish(f.options).applied,false);assert.equal(fs.existsSync(path.join(f.project,'Engine/assets')),false);
 f.install();assert.equal(publish(f.options).noop,true);const x=f.installed();assert.equal(fs.readFileSync(x.file,'utf8'),'one');
 assert.equal(x.r.contract,'gamepresentation-project-install-v1');assert.ok(x.r.assets[0].evidence.length);assert.equal(Object.keys(x.r.files).some(p=>/\.html$|snapshot|release\.json|approval|prompt/.test(p)),false);
 fs.renameSync(f.source,f.source+'-offline');fs.renameSync(path.join(f.project,'assets'),path.join(f.project,'assets-offline'));assert.equal(fs.readFileSync(x.file,'utf8'),'one');
});
test('changed source and gate evidence invalidate sealed release',t=>{
 const f=fixture(t);f.acquire();f.approve();f.release();f.put('project/assets/work/approval.md','Changed decision');assert.throws(()=>publish(f.options),/stale release/);
});
test('wrong desired mapping cannot publish',t=>{
 const f=fixture(t);f.acquire();f.approve();f.release();f.a.desired_release=null;f.save();assert.throws(()=>publish(f.options),/desired release mismatch/);
});
test('update and rollback restore previous owned bytes without touching owner file',t=>{
 const f=fixture(t);f.acquire();f.approve();f.release();f.install();const old=f.installed();fs.writeFileSync(path.join(old.c.dest,'owner.txt'),'owner');
 f.meta.files.normalized_sha256=sha(Buffer.from('two'));f.put('upstream/normalized/one.png','two');f.saveUpstream();f.acquire('v2');f.approve();f.release('v2');f.install('v2');assert.equal(fs.readFileSync(f.installed().file,'utf8'),'two');
 assert.equal(rollback({...f.options}).applied,false);rollback({...f.options,apply:true});assert.equal(fs.readFileSync(f.installed().file,'utf8'),'one');assert.equal(fs.readFileSync(path.join(old.c.dest,'owner.txt'),'utf8'),'owner');
});
test('owner media edit blocks update and rollback',t=>{
 const f=fixture(t);f.acquire();f.approve();f.release();f.install();const x=f.installed();fs.writeFileSync(x.file,'owner');
 assert.throws(()=>publish({...f.options,apply:true}),/modified or missing/);assert.throws(()=>rollback({...f.options,apply:true}),/modified or missing/);assert.equal(fs.readFileSync(x.file,'utf8'),'owner');
});
for(const phase of ['receive','seal','publish'])test(phase+' interruption is recoverable and retries do not silently overwrite journal',t=>{
 const f=fixture(t),fn={receive,seal,publish}[phase];if(phase!=='receive'){f.acquire();f.approve();}if(phase==='publish')f.release();
 assert.throws(()=>fn({...f.options,apply:true,failAfter:1}),/interruption/);assert.throws(()=>fn({...f.options,apply:true}),/pending/);
 assert.equal(recover({...f.options,phase}).applied,false);assert.equal(recover({...f.options,phase,apply:true}).applied,true);assert.equal(fn({...f.options,apply:true}).applied,true);
});
test('path traversal, overlapping roots, linked destinations, missing engine and conflicting folders fail',t=>{
 const f=fixture(t);assert.throws(()=>receive({...f.options,revision:'../bad'}),/invalid/);
 f.config.assets.directory='Engine/assets';f.put('project/maintenance/project-config.json',f.config);assert.throws(()=>receive(f.options),/overlap/);
 f.config.assets.directory='assets';f.put('project/maintenance/project-config.json',f.config);f.put('project/assets/sources/vendor/test/v1/owner.txt','owner');assert.throws(()=>receive({...f.options,apply:true}),/unowned/);
 const g=fixture(t);fs.unlinkSync(path.join(g.project,'Engine/project.godot'));assert.throws(()=>publish(g.options),/missing configured/);
 fs.mkdirSync(path.join(g.project,'assets/sources'),{recursive:true});fs.symlinkSync(g.source,path.join(g.project,'assets/sources/vendor'),'junction');assert.throws(()=>receive(g.options),/symbolic link/);
});
test('new release checker sees missing install, installed match, rollback drift and evidence edits',t=>{
 const f=fixture(t);f.acquire();f.approve();f.release();let r=checkAssets(f.project,f.config);assert.deepEqual(r.errors,[]);assert.match(r.warnings.join(' '),/not installed/);
 f.install();r=checkAssets(f.project,f.config);assert.deepEqual(r.errors,[]);assert.equal(r.counts.workbench_bundles,1);assert.equal(r.warnings.length,0);
 f.a.delivery={consumer:{filter:'linear'}};f.save();f.release('v2');f.install('v2');rollback({...f.options,apply:true});r=checkAssets(f.project,f.config);assert.deepEqual(r.errors,[]);assert.match(r.warnings.join(' '),/drift/);
 f.put('project/assets/work/approval.md','changed');assert.match(checkAssets(f.project,f.config).errors.join(' '),/hash mismatch/);
});
test('private processing recipe stays internal and source types cannot be laundered',t=>{
 const f=fixture(t);f.acquire();f.approve();f.a.delivery={processing:[{operation:'copy-source',private_prompt:'private recipe text',input:'internal/path'}]};f.save();f.release();f.install();assert.equal(JSON.stringify(f.installed().r).includes('private recipe'),false);assert.equal(JSON.stringify(f.installed().r).includes('internal/path'),false);
 f.a.source.kind='generated';f.save();assert.throws(()=>seal({...f.options,revision:'v2'}),/source kind mismatch/);
});
test('new generated receiver validates provenance, hashes, no-op and interruption recovery',t=>{
 const f=fixture(t),m={kind:'generated',assets:[{id:f.a.id,producer:'test-only',version:'unknown',prompt:'private',references:[],file:{path:'raw.png',sha256:sha(Buffer.from('raw'))}}]};
 f.put('upstream/raw.png','wrong');f.put('upstream/generation.json',m);assert.throws(()=>receiveGenerated(f.options),/hash mismatch/);
 f.put('upstream/raw.png','raw');assert.throws(()=>receiveGenerated({...f.options,apply:true,failAfter:1}),/interruption/);recover({...f.options,phase:'receive-generated',apply:true});receiveGenerated({...f.options,apply:true});assert.equal(receiveGenerated(f.options).noop,true);
 m.assets[0].prompt='changed prompt';f.put('upstream/generation.json',m);assert.throws(()=>receiveGenerated({...f.options,apply:true}),/immutable/);
});
test('missing reachable workflow contract blocks publication, not safe source acquisition',t=>{
 const f=fixture(t);f.acquire();f.approve();f.release();fs.unlinkSync(path.join(f.project,'contract.md'));assert.throws(()=>publish({...f.options,apply:true}),/contract unavailable/);
});
test('generated source rights are separate from tool/code licensing',t=>{
 const f=fixture(t);f.put('upstream/raw.png','generated');f.put('upstream/generation.json',{kind:'generated',assets:[{id:f.a.id,producer:'test-only',version:'unknown',prompt:'Private fixture prompt',references:[],file:{path:'raw.png',sha256:sha(Buffer.from('generated'))}}]});
 assert.equal(receiveGenerated(f.options).applied,false);const source=receiveGenerated({...f.options,apply:true});f.a.source=source.bindings[0].source;f.approve();assert.throws(()=>seal(f.options),/rights unresolved/);
 f.a.delivery={rights:{distribution_allowed:true,basis:'Synthetic test permission only',evidence:['assets/work/approval.md']}};f.save();f.release();f.install();assert.equal(f.installed().r.assets[0].license,'project-rights-reviewed');
 assert.equal(JSON.stringify(f.installed().r).includes('Private fixture prompt'),false);assert.equal(receiveGenerated(f.options).noop,true);
});
test('release and snapshot tampering fail before engine writes',t=>{
 const f=fixture(t);f.acquire();f.approve();const r=f.release();const dir=r.destination,release=JSON.parse(fs.readFileSync(path.join(dir,'release.json')));fs.writeFileSync(path.join(dir,release.assets[0].path),'tamper');
 assert.throws(()=>publish({...f.options,apply:true}),/modified or missing/);assert.equal(fs.existsSync(path.join(f.project,'Engine/assets')),false);
});
