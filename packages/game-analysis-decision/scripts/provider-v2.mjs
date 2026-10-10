import fs from 'node:fs';
import {lookup,containedPath,repositoryRoot,resolveKnowledge} from './learning-cli.mjs';
export function selectProfessional(query={},root=repositoryRoot,{maxAssets=3,maxCharacters=20000}={}){
 const allowed=['query','ids','roles','includeCandidates','contextTags'];
 if(!query||typeof query!=='object'||Array.isArray(query)||Object.keys(query).some(k=>!allowed.includes(k)))throw new Error('Unknown professional selection field');
 if(!Number.isInteger(maxAssets)||maxAssets<1||maxAssets>32||!Number.isInteger(maxCharacters)||maxCharacters<100||maxCharacters>100000)throw new Error('Invalid reading budget');
 const matches=lookup(query,root),selected=[];let used=0;
 for(const item of matches){
  if(selected.length>=maxAssets)break;
  const content=fs.readFileSync(containedPath(root,item.path),'utf8');
  if(used+content.length>maxCharacters)continue;
  selected.push({...item,content});used+=content.length;
 }
 return {schema_version:2,status:matches.length===selected.length?'complete':'partial',candidate_policy:query.includeCandidates===true?'explicit_opt_in':'excluded_by_default',assets:selected,not_loaded:matches.filter(m=>!selected.some(s=>s.id===m.id)).map(m=>m.id),content_characters:used,source_plan:[...new Set(selected.flatMap(a=>a.source_refs))],sources_read:false,host_write:false,claim:'Matched professional content with actual current eligibility. Candidates require explicit opt-in for a concrete analytical gap; scoped content requires matching context. Selection is not expertise or quality certification; read scope and verify critical conclusions.'};
}
export {resolveKnowledge as resolveSourceV2};
