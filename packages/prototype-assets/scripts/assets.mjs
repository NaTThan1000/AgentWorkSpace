#!/usr/bin/env node
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {safe,sha,desired} from './vendor-delivery.mjs';
export const root=path.resolve(import.meta.dirname,'..');
const fail=s=>{throw Error(s);};
export function list(source=root){
 return ['assets.json','formal-assets.json'].flatMap(n=>JSON.parse(fs.readFileSync(safe(source,'catalog/'+n),'utf8')).assets);
}
export function verify(source=root){
 const assets=list(source),ids=assets.map(a=>a.asset_id);
 if(new Set(ids).size!==ids.length)fail('duplicate asset ID');
 for(const id of ids)desired(source,[id]);
 return {verified:assets.length,claim:'Source/rights receipts and bytes checked; actual engine and usage validation are separate.'};
}
export function exportAssets({source=root,target,ids,consumer='godot',apply=false}){
 if(!['godot','fromdemotospec'].includes(consumer))fail('unknown consumer');
 if(consumer==='fromdemotospec'){
  const base=JSON.parse(fs.readFileSync(safe(source,'catalog/assets.json'),'utf8')).assets;
  if(ids.some(id=>!base.some(a=>a.asset_id===id)))fail('FromDemoToSpec supports the base 2D catalog only');
 }
 const d=desired(source,ids);target=safe(target);
 const sourceRoot=path.resolve(source);
 if(target===sourceRoot||target.startsWith(sourceRoot+path.sep)||sourceRoot.startsWith(target+path.sep))fail('source and target overlap');
 // Audit pages are not redistributed as runtime assets. Actual license text remains mandatory.
 for(const n of Object.keys(d.files))if(n.endsWith('.html'))delete d.files[n];
 for(const a of d.selected){a.evidence=a.evidence.filter(n=>n in d.files);if(!a.evidence.some(n=>/\.(txt|md)$/i.test(n)))fail('license text unavailable');}
 const hashes=Object.fromEntries(Object.entries(d.files).map(([n,b])=>[n,sha(Buffer.from(b,'base64'))]));
 d.files['receipt.json']=Buffer.from(JSON.stringify({contract:'prototype-assets-export-v1',consumer,assets:d.selected,files:hashes},null,2)+'\n').toString('base64');
 if(fs.existsSync(target)&&fs.readdirSync(target).length){
  const files=[];
  function walk(dir,prefix=''){for(const n of fs.readdirSync(dir)){const rel=prefix+n,p=safe(target,rel);if(fs.statSync(p).isDirectory())walk(p,rel+'/');else files.push(rel);}}
  walk(target);
  if(files.length!==Object.keys(d.files).length||files.some(n=>!(n in d.files)||fs.readFileSync(safe(target,n)).toString('base64')!==d.files[n]))fail('target contains different or unowned files');
  return {applied:false,noop:true,files:files.length};
 }
 if(!apply)return {applied:false,files:Object.keys(d.files),ids};
 fs.mkdirSync(path.dirname(target),{recursive:true});
 const staged=safe(path.dirname(target),'.asset-export-'+crypto.randomUUID());
 fs.mkdirSync(staged);
 try{
  for(const [n,b] of Object.entries(d.files)){const p=safe(staged,n);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,Buffer.from(b,'base64'),{flag:'wx'});}
  if(fs.existsSync(target)){if(fs.readdirSync(target).length)fail('target changed during export');fs.rmdirSync(target);}
  fs.renameSync(staged,target);
 }finally{if(fs.existsSync(staged))fs.rmSync(staged,{recursive:true,force:true});}
 return {applied:true,files:Object.keys(d.files).length,ids};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const [action,...args]=process.argv.slice(2),opts={ids:[]};
  while(args.length){const k=args.shift();if(k==='--apply')opts.apply=true;else if(k==='--ids'){while(args.length&&!args[0].startsWith('--'))opts.ids.push(args.shift());}else if(['--target','--consumer'].includes(k)){const v=args.shift();if(!v||v.startsWith('--'))fail('missing '+k);opts[k.slice(2)]=v;}else fail('unknown option: '+k);}
  if(action==='list'&&Object.keys(opts).length===1)console.log(JSON.stringify(list().map(a=>({id:a.asset_id,category:a.category,license:a.license.spdx})),null,2));
  else if(action==='verify'&&Object.keys(opts).length===1)console.log(JSON.stringify(verify(),null,2));
  else if(action==='export'&&opts.target&&opts.ids.length)console.log(JSON.stringify(exportAssets(opts),null,2));
  else fail('Usage: assets.mjs list | verify | export --ids <id...> --target <new-directory> [--consumer godot|fromdemotospec] [--apply]');
 }catch(e){console.error(e.message);process.exitCode=2;}
}
