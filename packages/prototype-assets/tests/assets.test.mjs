import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {root,list,verify,exportAssets} from '../scripts/assets.mjs';
test('all real shipped assets have matching provenance and bytes',()=>{assert.ok(verify().verified>0);});
test('export preview, copy, no-op, conflict and independent runtime',t=>{
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'assets-export-'));t.after(()=>fs.rmSync(temp,{recursive:true,force:true}));
 const target=path.join(temp,'bundle'),ids=[list()[0].asset_id];
 assert.equal(exportAssets({target,ids}).applied,false);assert.equal(fs.existsSync(target),false);
 assert.equal(exportAssets({target,ids,apply:true}).applied,true);
 const r=JSON.parse(fs.readFileSync(path.join(target,'receipt.json')));
 assert.ok(r.assets[0].evidence.some(n=>n.endsWith('.txt')));assert.ok(!Object.keys(r.files).some(n=>n.endsWith('.html')));
 assert.equal(exportAssets({target,ids,apply:true}).noop,true);
 fs.writeFileSync(path.join(target,'mine.txt'),'keep');
 assert.throws(()=>exportAssets({target,ids,apply:true}),/unowned/);assert.equal(fs.readFileSync(path.join(target,'mine.txt'),'utf8'),'keep');
 assert.throws(()=>exportAssets({target:path.join(temp,'bad'),ids:['missing']}),/unknown ID/);
 assert.throws(()=>exportAssets({target:root,ids}),/overlap/);
});
test('FromDemoToSpec export keeps the base catalog boundary',t=>{
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'assets-f2s-'));t.after(()=>fs.rmSync(temp,{recursive:true,force:true}));
 const a=JSON.parse(fs.readFileSync(path.join(root,'catalog/formal-assets.json'))).assets[0];
 assert.throws(()=>exportAssets({target:path.join(temp,'bad'),ids:[a.asset_id],consumer:'fromdemotospec'}),/base 2D/);
});
