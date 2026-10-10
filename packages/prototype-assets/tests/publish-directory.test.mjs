import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {publishDirectory} from '../scripts/publish-directory.mjs';
function fixture(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'publish-dir-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true,maxRetries:5,retryDelay:100}));const staged=path.join(dir,'staged'),target=path.join(dir,'target');fs.mkdirSync(staged);fs.writeFileSync(path.join(staged,'keep.txt'),'complete');return {staged,target};}
test('transient Windows rename errors recover without partial publication',t=>{
 const {staged,target}=fixture(t),waits=[];let attempts=0;
 publishDirectory(staged,target,{platform:'win32',wait:ms=>waits.push(ms),rename:(a,b)=>{if(attempts++<2)throw Object.assign(Error('temporary access'),{code:'EPERM'});fs.renameSync(a,b);}});
 assert.deepEqual(waits,[25,50]);assert.equal(attempts,3);assert.equal(fs.existsSync(staged),false);assert.equal(fs.readFileSync(path.join(target,'keep.txt'),'utf8'),'complete');
});
test('persistent denial is bounded and preserves the complete staging input',t=>{
 const {staged,target}=fixture(t);let attempts=0;const denial=Object.assign(Error('persistent access denied'),{code:'EPERM'});
 assert.throws(()=>publishDirectory(staged,target,{platform:'win32',wait:()=>{},rename:()=>{attempts++;throw denial;}}),e=>e===denial);
 assert.equal(attempts,7);assert.equal(fs.existsSync(target),false);assert.equal(fs.readFileSync(path.join(staged,'keep.txt'),'utf8'),'complete');
});
test('another writer appearing during retry is preserved',t=>{
 const {staged,target}=fixture(t);
 assert.throws(()=>publishDirectory(staged,target,{platform:'win32',rename:()=>{throw Object.assign(Error('temporary'),{code:'EBUSY'});},wait:()=>{fs.mkdirSync(target);fs.writeFileSync(path.join(target,'mine.txt'),'user');}}),/destination appeared/);
 assert.equal(fs.readFileSync(path.join(target,'mine.txt'),'utf8'),'user');assert.equal(fs.readFileSync(path.join(staged,'keep.txt'),'utf8'),'complete');
});
test('non-Windows and unrelated errors fail immediately',t=>{
 const {staged,target}=fixture(t);
 for(const [platform,code] of [['linux','EPERM'],['win32','EIO']]){let attempts=0;
  assert.throws(()=>publishDirectory(staged,target,{platform,wait:()=>assert.fail('must not wait'),rename:()=>{attempts++;throw Object.assign(Error('fail'),{code});}}),e=>e.code===code);assert.equal(attempts,1);
 }
});
