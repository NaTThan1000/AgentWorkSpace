#!/usr/bin/env node
import fs from 'node:fs';
import {publishDirectory} from './publish-directory.mjs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {safe} from '../adapters/godot/deliver.mjs';
export function initProject({target,apply=false}){
 target=safe(target);
 const packageRoot=path.resolve(import.meta.dirname,'..');
 if(target===packageRoot||target.startsWith(packageRoot+path.sep)||packageRoot.startsWith(target+path.sep))throw Error('package and project must be separate');
 if(fs.existsSync(target)&&fs.readdirSync(target).length)throw Error('target must be empty; existing projects integrate explicitly');
 const files={
  'README.md':'# Presentation project\n\nProject facts and adoption belong here. Asset specification and rights are required before seal/publish. Check actual Godot behavior separately.\n',
  'Engine/project.godot':'config_version=5\n\n[application]\nconfig/name="Presentation project"\n',
  'maintenance/project-config.json':JSON.stringify({engine:{directory:'Engine'},assets:{directory:'assets',contract_version:1,workflow_contract:'docs/asset-contract.md',legacy_receipts:[]}},null,2)+'\n',
  'assets/catalog.json':JSON.stringify({schema_version:1,assets:[]},null,2)+'\n',
  'docs/asset-contract.md':'# Asset contract v1\n\nProjects own sources, purpose, specifications and concept/purpose/technical/rights gates. Gates need actual evidence and adopted states before release. Generated sources retain tool/version/prompt/references/hash; distribution rights require an explicit basis and evidence. No automatic product approval. Preview first, preserve unrelated work, use owned transactions and engine tests.\n',
  '.gitignore':'Engine/.godot/\nmaintenance/asset-deliveries/\n'};
 if(apply){
  fs.mkdirSync(path.dirname(target),{recursive:true});
  const staged=safe(path.dirname(target),'.gp-init-'+crypto.randomUUID());fs.mkdirSync(staged);
  try{
   for(const [n,b] of Object.entries(files)){const p=safe(staged,n);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,b,{flag:'wx'});}
   if(fs.existsSync(target)){if(fs.readdirSync(target).length)throw Error('target changed during preparation');fs.rmdirSync(target);}
   publishDirectory(staged,target);
  }finally{if(fs.existsSync(staged))fs.rmSync(staged,{recursive:true,force:true,maxRetries:5,retryDelay:100});}
 }
 return {applied:apply,files:Object.keys(files),engine_verified:false};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const args=process.argv.slice(2),opts={};while(args.length){const k=args.shift();if(k==='--apply')opts.apply=true;else if(k==='--target')opts.target=args.shift();else throw Error('unknown option: '+k);}if(!opts.target)throw Error('--target required');console.log(JSON.stringify(initProject(opts),null,2));}catch(e){console.error(e.message);process.exitCode=2;}
}
