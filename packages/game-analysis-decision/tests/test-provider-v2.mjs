import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {selectProfessional,resolveSourceV2} from '../scripts/provider-v2.mjs';
import {repositoryRoot,loadCatalogue,containedPath} from '../scripts/learning-cli.mjs';
const cat=loadCatalogue();
assert.deepEqual(selectProfessional().assets,[]);
const ids=cat.assets.slice(0,4).map(a=>a.id);
const defaults=selectProfessional({ids},repositoryRoot);
assert.deepEqual(defaults.assets,[],'Naming candidates alone must not load them');
assert.equal(defaults.candidate_policy,'excluded_by_default');
assert.deepEqual(selectProfessional({roles:['NUM'],query:'资源'},repositoryRoot).assets,[]);
const result=selectProfessional({ids,includeCandidates:true},repositoryRoot,{maxAssets:2,maxCharacters:20000});
assert.equal(result.candidate_policy,'explicit_opt_in');
assert.equal(result.assets.length,2);assert.equal(result.status,'partial');assert.equal(result.not_loaded.length,2);assert.equal(result.sources_read,false);
for(const asset of result.assets){
 assert.equal(asset.content,fs.readFileSync(containedPath(repositoryRoot,asset.path),'utf8'));
 assert.equal(asset.sha256,crypto.createHash('sha256').update(asset.content).digest('hex'));
 assert.equal(asset.sole_basis_for_important_decision,false);
}
assert.throws(()=>selectProfessional({ids:['PRO-PM-002-automation-production-boundary-audit']}),/retired/);
assert.throws(()=>selectProfessional({unrecognized:true}),/Unknown/);
assert.throws(()=>selectProfessional({},repositoryRoot,{maxAssets:0}),/budget/);
const low=selectProfessional({ids,includeCandidates:true},repositoryRoot,{maxCharacters:100,maxAssets:2});
assert.equal(low.assets.length,0);assert.equal(low.status,'partial');
assert.equal(resolveSourceV2('knowledge:domain:missing',containedPath(repositoryRoot,'tests')).status,'unavailable');
console.log('PASS: actual v2 professional content selection, no blanket loading, source plan disclosure, file hashes, reading caps, retired and unknown field rejection.');
