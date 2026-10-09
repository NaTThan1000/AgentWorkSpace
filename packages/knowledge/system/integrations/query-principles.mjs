import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
export const knowledgeRoot=path.resolve(import.meta.dirname,'../..');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
function safe(root,rel){
 const base=fs.realpathSync(root),filename=fs.realpathSync(path.resolve(root,rel)),r=path.relative(base,filename);
 if(path.isAbsolute(r)||r==='..'||r.startsWith('..'+path.sep))throw new Error('Source path escapes Knowledge');
 return filename;
}
export function listDomains(root=knowledgeRoot){
 return fs.readdirSync(safe(root,'domains')).filter(n=>n.endsWith('.md')&&n!=='README.md'&&!n.endsWith('.template.md')).sort().map(n=>n.slice(0,-3));
}
export function readDomain(domain,root=knowledgeRoot){
 if(typeof domain!=='string'||/[\\/:]/.test(domain)||['.','..'].includes(domain))throw new Error('Invalid domain name');
 const p=safe(root,'domains/'+domain+'.md'),body=fs.readFileSync(p,'utf8');
 const section=body.split(/^## 领域设计原则\s*$/m)[1]??'';
 const blocks=section.split(/(?=^\d+\.\s+\*\*)/m),items=[];
 for(const b of blocks){
  const id=/<!--\s*principle_id:\s*(DPR-[A-Z]+-\d+)\s*-->/.exec(b)?.[1];if(!id)continue;
  const content=b.split(/^###?\s/m)[0].trim();
  const sources=[...content.matchAll(/\[[^\]]+\]\(<?(\.\.\/wiki\/[^)>]+|https:\/\/[^)>]+)>?\)/g)].map(m=>m[1]);
  const normalized=content.replace(/<!--[^]*?-->/g,'').replace(/\s+/g,' ').trim();
  items.push({id,ref:'knowledge:principle:'+id,domain,content,semantic_candidate_sha256:hash(normalized),sources,source_ref:'knowledge:domain:'+domain,source_path:'domains/'+domain+'.md',source_sha256:hash(body),applicability:'requires_task_review',claim_support:'not_verified'});
 }
 const seen=new Set();for(const p of items){if(seen.has(p.id))throw new Error('Duplicate principle ID');seen.add(p.id);}
 return {domain,source_sha256:hash(body),principles:items};
}
export function queryPrinciples({domains=[],ids=[],query=''}={},root=knowledgeRoot){
 if(!Array.isArray(domains)||!Array.isArray(ids)||typeof query!=='string'||[...domains,...ids].some(s=>typeof s!=='string'))throw new Error('Invalid principle query');
 if(ids.some(id=>!/^DPR-[A-Z]+-\d+$/.test(id)))throw new Error('Invalid principle ID');
 if(!domains.length&&!ids.length)return {principles:[],reason:'No domain or ID selected; ordinary Query need not load principles',writes:false};
 const all=(domains.length?domains:listDomains(root)).flatMap(d=>readDomain(d,root).principles);
 if(new Set(all.map(p=>p.id)).size!==all.length)throw new Error('Duplicate principle IDs across domains');
 const missing=ids.filter(id=>!all.some(p=>p.id===id));if(missing.length)return {principles:[],status:'unavailable',missing,writes:false};
 const tokens=query.split(/[\s,，、]+/u).filter(Boolean);
 return {principles:all.filter(p=>(!ids.length||ids.includes(p.id))&&(!tokens.length||tokens.some(t=>p.content.includes(t)))),writes:false,claim:'Candidates only; read conditions and cited Wiki, trace raw for important claims under Query policy'};
}
function main(){
 const [action,arg]=process.argv.slice(2);
 if(action==='list'){console.log(JSON.stringify({domains:listDomains(),writes:false}));return;}
 if(action==='get'){console.log(JSON.stringify(queryPrinciples({ids:[arg.replace(/^knowledge:principle:/,'')]}),null,2));return;}
 if(action==='query'){console.log(JSON.stringify(queryPrinciples(JSON.parse(fs.readFileSync(arg,'utf8'))),null,2));return;}
 throw new Error('Usage: query-principles.mjs list | get <DPR-ID|knowledge:principle:ID> | query <json>');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){try{main();}catch(e){console.error(e.message);process.exitCode=2;}}
