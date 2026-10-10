import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {deliver,rollback,recover,sha} from '../adapters/godot/deliver.mjs';
function fixture(t){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'gp-delivery-'));
 t.after(()=>{assert.ok(root.startsWith(path.join(os.tmpdir(),'gp-delivery-')));fs.rmSync(root,{recursive:true,force:true});});
 const source=path.join(root,'source'), project=path.join(root,'project'), engine=path.join(project,'Engine');
 const put=(rel,bytes)=>{const p=path.join(root,rel);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,typeof bytes==='object'&&!Buffer.isBuffer(bytes)?JSON.stringify(bytes):bytes);};
 put('project/Engine/project.godot','config_version=5');
 put('project/maintenance/project-config.json',{engine:{directory:'Engine'}});
 put('source/normalized/one.png',Buffer.from('fixture-png-one'));
 put('source/normalized/two.wav',Buffer.from('fixture-wav-two'));
 put('source/licenses/LICENSE.txt','Fixture CC0 license evidence; not an actual distributable asset.');
 const receipt={public_release_allowed:true,license_spdx:'CC0-1.0',source_url:'https://fixture.invalid/pack',evidence_paths:['licenses/LICENSE.txt']};
 put('source/licenses/receipt.json',receipt);
 const assets=['one.png','two.wav'].map(n=>({asset_id:'test:'+n,source:{url:receipt.source_url},license:{spdx:'CC0-1.0',receipt_path:'licenses/receipt.json'},public_release_allowed:true,normalized_path:'normalized/'+n,files:{original_sha256:sha(fs.readFileSync(path.join(source,'normalized',n))),normalized_sha256:sha(fs.readFileSync(path.join(source,'normalized',n)))}}));
 const sources=[{source_url:receipt.source_url,license_spdx:'CC0-1.0',receipt_path:'licenses/receipt.json',public_release_allowed:true}];
 const save=()=>{put('source/catalog/assets.json',{assets});put('source/catalog/sources.json',{sources});put('source/licenses/receipt.json',receipt);};
 save();
 const options={source,engine,bundle:'test',ids:['test:one.png']};
 const dest=path.join(engine,'assets/vendor/test');
 const assetPath=()=>path.join(dest,JSON.parse(fs.readFileSync(path.join(dest,'receipt.json'))).assets[0].path);
 return {root,source,engine,put,assets,sources,receipt,save,options,dest,assetPath};
}
test('formal Godot catalog is additive; no F2S export fields needed',t=>{
 const f=fixture(t);
 const a={...f.assets[1],asset_id:'formal:audio',consumers:['godot'],processing:[{operation:'unmodified-copy'}]};
 f.put('source/catalog/formal-assets.json',{schema_version:1,assets:[a]});
 f.put('source/catalog/formal-sources.json',{schema_version:1,sources:f.sources});
 deliver({...f.options,ids:['test:one.png','formal:audio'],apply:true});
 const r=JSON.parse(fs.readFileSync(path.join(f.dest,'receipt.json')));
 assert.equal(r.assets.length,2);assert.equal(r.assets.find(x=>x.asset_id==='formal:audio').processing[0].operation,'unmodified-copy');
});
test('formal catalog rejects unsupported consumers and duplicate IDs across catalogs',t=>{
 const f=fixture(t);
 const a={...f.assets[0],consumers:['f2s']};
 f.put('source/catalog/formal-assets.json',{schema_version:1,assets:[a]});
 f.put('source/catalog/formal-sources.json',{schema_version:1,sources:f.sources});
 assert.throws(()=>deliver(f.options),/not approved for Godot/);
 a.consumers=['godot'];f.put('source/catalog/formal-assets.json',{schema_version:1,assets:[a]});
 assert.throws(()=>deliver(f.options),/duplicate catalog ID/);
});
test('dry run has no destination writes; apply copies evidence; duplicate is no-op',t=>{
 const f=fixture(t), p=deliver(f.options);assert.equal(p.applied,false);assert.equal(fs.existsSync(f.dest),false);
 assert.ok(p.changes.some(x=>x.path==='receipt.json'));
 const a=deliver({...f.options,apply:true});assert.equal(a.applied,true);
 const r=JSON.parse(fs.readFileSync(path.join(f.dest,'receipt.json')));assert.equal(r.assets[0].license,'CC0-1.0');assert.ok(r.assets[0].evidence.length>=2);
 assert.ok(r.files['.gitattributes']);assert.match(fs.readFileSync(path.join(f.dest,'.gitattributes'),'utf8'),/\* -text/);
 assert.equal(deliver({...f.options,apply:true}).noop,true);
});
test('update adds/removes, rollback restores previous bytes and unrelated files',t=>{
 const f=fixture(t);deliver({...f.options,apply:true});const old=fs.readFileSync(f.assetPath());
 fs.writeFileSync(path.join(f.dest,'personal.txt'),'keep me');
 deliver({...f.options,ids:['test:two.wav'],apply:true});
 assert.equal(path.extname(f.assetPath()),'.wav');
 const preview=rollback(f.options);assert.equal(preview.applied,false);
 rollback({...f.options,apply:true});assert.deepEqual(fs.readFileSync(f.assetPath()),old);
 assert.equal(fs.readFileSync(path.join(f.dest,'personal.txt'),'utf8'),'keep me');
});
test('first import rollback removes only owned files, retains empty ownership receipt',t=>{
 const f=fixture(t);deliver({...f.options,apply:true});const p=f.assetPath();
 fs.writeFileSync(path.join(f.dest,'mine.txt'),'keep');
 rollback({...f.options,apply:true});assert.equal(fs.existsSync(p),false);assert.ok(fs.existsSync(path.join(f.dest,'mine.txt')));
 assert.deepEqual(JSON.parse(fs.readFileSync(path.join(f.dest,'receipt.json'))).assets,[]);
});
for(const [name,mutate,pattern] of [
 ['unknown ID',f=>f.options.ids=['unknown'],/unknown ID/],
 ['duplicate IDs',f=>f.options.ids.push(f.options.ids[0]),/duplicate IDs/],
 ['source hash',f=>f.put('source/normalized/one.png','modified'),/hash mismatch/],
 ['asset approval',f=>{f.assets[0].public_release_allowed=false;f.save();},/not approved/],
 ['receipt approval',f=>{f.receipt.public_release_allowed=false;f.save();},/receipt approval/],
 ['license mismatch',f=>{f.receipt.license_spdx='MIT';f.save();},/receipt approval/],
 ['unknown license',f=>{f.assets[0].license.spdx='unknown';f.save();},/unsupported license/],
 ['unregistered source',f=>{f.sources.length=0;f.save();},/unregistered source/],
 ['missing evidence',f=>fs.unlinkSync(path.join(f.source,'licenses/LICENSE.txt')),/ENOENT/],
 ['empty evidence',f=>{f.receipt.evidence_paths=[];f.save();},/missing license evidence/],
 ['path traversal',f=>{f.assets[0].normalized_path='../outside.png';f.save();},/unsafe path/],
 ['absolute path',f=>{f.assets[0].normalized_path=path.join(f.root,'outside.png');f.save();},/unsafe path/],
 ['invalid bundle',f=>f.options.bundle='../test',/invalid bundle/]
]) test('reject '+name,t=>{const f=fixture(t);mutate(f);assert.throws(()=>deliver({...f.options,apply:true}),pattern);assert.equal(fs.existsSync(f.dest),false);});
test('modified or missing owned file blocks update and rollback',t=>{
 const f=fixture(t);deliver({...f.options,apply:true});fs.writeFileSync(f.assetPath(),'user change');
 assert.throws(()=>deliver({...f.options,apply:true}),/modified or missing/);assert.throws(()=>rollback({...f.options,apply:true}),/modified or missing/);
 fs.unlinkSync(f.assetPath());assert.throws(()=>deliver({...f.options,apply:true}),/modified or missing/);
});
test('new collision and non-owned destination block writes',t=>{
 const f=fixture(t);fs.mkdirSync(f.dest,{recursive:true});fs.writeFileSync(path.join(f.dest,'mine.txt'),'keep');
 assert.throws(()=>deliver({...f.options,apply:true}),/unowned destination/);
});
test('new file collision inside owned bundle blocks update',t=>{
 const f=fixture(t);deliver({...f.options,apply:true});
 const p=deliver({...f.options,ids:['test:one.png','test:two.wav']}).changes.find(x=>x.path.endsWith('.wav')).path;
 fs.writeFileSync(path.join(f.dest,p),'user-owned');
 assert.throws(()=>deliver({...f.options,ids:['test:one.png','test:two.wav'],apply:true}),/unowned file collision/);
});
test('interruption retains journal, blocks import and recovers without source',t=>{
 const f=fixture(t);deliver({...f.options,apply:true});const original=fs.readFileSync(f.assetPath());
 assert.throws(()=>deliver({...f.options,ids:['test:two.wav'],apply:true,failAfter:1}),/injected interruption/);
 assert.throws(()=>deliver(f.options),/recover first/);
 fs.renameSync(f.source,f.source+'-unavailable');
 assert.equal(recover(f.options).applied,false);assert.equal(recover({...f.options,apply:true}).applied,true);
 assert.deepEqual(fs.readFileSync(f.assetPath()),original);
 assert.equal(recover({...f.options,apply:true}).noop,true);
});
test('recovery refuses unexpected edits after interruption',t=>{
 const f=fixture(t);deliver({...f.options,apply:true});
 assert.throws(()=>deliver({...f.options,ids:['test:two.wav'],apply:true,failAfter:1}));
 fs.writeFileSync(f.assetPath(),'manual');
 assert.throws(()=>recover({...f.options,apply:true}),/recovery conflict/);
 assert.equal(fs.readFileSync(f.assetPath(),'utf8'),'manual');
});
test('links cannot escape source or destination',t=>{
 const f=fixture(t);const outside=path.join(f.root,'outside');fs.mkdirSync(outside);
 fs.symlinkSync(outside,path.join(f.source,'linked'),'junction');f.assets[0].normalized_path='linked/one.png';f.save();
 assert.throws(()=>deliver({...f.options,apply:true}),/symbolic link/);
});
