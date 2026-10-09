import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const here=fileURLToPath(import.meta.url);
const defaultRoot=path.resolve(path.dirname(here),'..');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const stable=value=>JSON.stringify(value);
function fail(message){throw new Error('Brainstorm method learning: '+message);}
function text(value,key){if(typeof value!=='string'||!value.trim())fail(key+' must be nonempty');}
function contained(root,relative){
 text(relative,'path');
 if(path.isAbsolute(relative)||relative.includes('\\')||relative.split('/').some(x=>x==='..'||!x))fail('Unsafe relative path');
 const target=path.resolve(root,relative);
 const realRoot=fs.realpathSync(root),real=fs.realpathSync(target);
 if(!real.startsWith(realRoot+path.sep))fail('Path escapes repository');
 return target;
}
function verifyFile(root,item){
 if(!item||typeof item!=='object')fail('File evidence required');
 if(!/^[a-f0-9]{64}$/.test(item.sha256||''))fail('Invalid sha256');
 const target=contained(root,item.path);
 if(!fs.statSync(target).isFile())fail('Expected file');
 if(hash(fs.readFileSync(target))!==item.sha256)fail('File hash mismatch: '+item.path);
 return target;
}
export function validateLearning(value,{root=defaultRoot}={}){
 if(!value||typeof value!=='object'||Array.isArray(value))fail('Record must be an object');
 const required=['schema_version','id','kind','trigger','source_refs','scope','disposition','targets','evidence','limitations'];
 const keys=Object.keys(value);
 if(required.some(k=>!keys.includes(k))||keys.some(k=>![...required,'prior_id'].includes(k)))fail('Missing or unknown fields');
 if(value.schema_version!==1||!/^ML-[a-z0-9][a-z0-9-]{2,80}$/.test(value.id||''))fail('Invalid schema or id');
 if(!['correction','strategy','counterexample'].includes(value.kind))fail('Unknown kind');
 if(!['trial','scoped','withdrawn'].includes(value.disposition))fail('Unknown disposition');
 for(const key of ['trigger','scope','limitations'])text(value[key],key);
 if(/^(global|all|universal|all tasks|all models|全部|所有|通用|全局)$/i.test(value.scope.trim()))fail('Scope must be bounded');
 if(!Array.isArray(value.source_refs)||!value.source_refs.length)fail('Sources required');
 for(const ref of value.source_refs)text(ref,'source_refs');
 if(!Array.isArray(value.targets)||!value.targets.length)fail('Targets required');
 const seen=new Set();
 for(const item of value.targets){
  if(!item||typeof item!=='object'||Array.isArray(item))fail('Learning target must be an object');
  if(!/^(methods\/|perspectives\/|examples\/co-creation\/)/.test(item.path||''))fail('Learning target outside content scope');
  if(seen.has(item.path))fail('Duplicate target');seen.add(item.path);
  verifyFile(root,item);
 }
 if(!Array.isArray(value.evidence))fail('Evidence must be an array');
 for(const item of value.evidence){
  verifyFile(root,item);text(item.check,'evidence.check');
  if(!['passed','failed','mixed'].includes(item.result))fail('Invalid evidence result');
 }
 if(value.disposition==='scoped'&&!value.evidence.some(x=>x.result==='passed'))fail('Scoped adoption requires a passed check');
 if(value.kind==='strategy'&&value.disposition==='scoped'&&!value.prior_id)fail('A new strategy starts as trial');
 if(value.disposition==='withdrawn'&&(!value.prior_id||!value.evidence.length))fail('Withdrawal requires prior record and counterevidence');
 if(value.prior_id){
  if(!/^ML-[a-z0-9][a-z0-9-]{2,80}$/.test(value.prior_id)||value.prior_id===value.id)fail('Invalid prior id');
  const priorPath=contained(root,'docs/learning-records/'+value.prior_id+'.json');
  const prior=JSON.parse(fs.readFileSync(priorPath,'utf8'));
  if(prior.id!==value.prior_id)fail('Prior identity mismatch');
  if(!value.targets.some(x=>prior.targets.some(p=>p.path===x.path)))fail('Prior record is unrelated to target');
  if(value.disposition==='withdrawn'&&value.targets.every(x=>prior.targets.some(p=>p.path===x.path&&p.sha256===x.sha256)))fail('Withdrawal must update actual content or routing');
 }
 return {structure_passed:true,semantic_review_required:true,id:value.id,disposition:value.disposition,
   effect_proven:false,method_modified:false,knowledge_write:false,global_profile_write:false};
}
export function recordLearning(value,{root=defaultRoot}={}){
 const result=validateLearning(value,{root});
 const directory=path.resolve(root,'docs/learning-records');
 const realRoot=fs.realpathSync(root);
 let ancestor=directory;while(!fs.existsSync(ancestor))ancestor=path.dirname(ancestor);
 const realAncestor=fs.realpathSync(ancestor);
 if(realAncestor!==realRoot&&!realAncestor.startsWith(realRoot+path.sep))fail('Record directory escapes repository');
 fs.mkdirSync(directory,{recursive:true});
 const realDirectory=fs.realpathSync(directory);
 if(!realDirectory.startsWith(realRoot+path.sep))fail('Record directory escapes repository');
 const target=path.join(directory,value.id+'.json');
 if(fs.existsSync(target)){
  const existing=JSON.parse(fs.readFileSync(contained(root,'docs/learning-records/'+value.id+'.json'),'utf8'));
  if(stable(existing)!==stable(value))fail('Record id already exists with different content');
  return {...result,recorded:false,idempotent:true};
 }
 fs.writeFileSync(target,JSON.stringify(value,null,2)+'\n',{encoding:'utf8',flag:'wx'});
 return {...result,recorded:true,idempotent:false,record_path:'docs/learning-records/'+value.id+'.json'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===here){
 try{
  const [command,...args]=process.argv.slice(2),i=args.indexOf('--input');
  if(!['validate','record'].includes(command)||i<0||!args[i+1])fail('Usage: validate|record --input file.json');
  const value=JSON.parse(fs.readFileSync(path.resolve(args[i+1]),'utf8'));
  const result=command==='record'?recordLearning(value):validateLearning(value);
  process.stdout.write(JSON.stringify(result,null,2)+'\n');
 }catch(error){process.stderr.write(error.message+'\n');process.exitCode=1;}
}
