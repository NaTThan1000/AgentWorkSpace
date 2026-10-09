import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
const defaultModule=new URL('../../GameAnalysisDecision/scripts/adapter-v2.mjs',import.meta.url);
const hostType='brainstorm';
function identity(value){
 if(value?.schema_version!==2||value.adapter_id!==hostType+'-adapter'||typeof value.host_ref!=='string'||!value.host_ref.startsWith(hostType+':'))throw new Error('Wrong GAD v2 host identity');
 if(typeof value.host_write_target_ref!=='string'||!value.host_write_target_ref.startsWith(hostType+':'))throw new Error('Wrong host write target');
 if(hostType==='brainstorm'&&!value.host_write_target_ref.startsWith(value.host_ref+'#'))throw new Error('Target must remain in the same session');
}
export function unavailableV2(value){
 identity(value);
 return {schema_version:2,request_id:value.request_id,host_ref:value.host_ref,gad_status:'unavailable',next_action:'continue_normal_host_flow',reason:'GAD v2 module is absent; no analysis was run',automatic_expert_fallback:false,host_write:false,formal_decision_written:false};
}
async function engine(moduleUrl=defaultModule){
 if(!fs.existsSync(fileURLToPath(moduleUrl)))return null;
 return import(moduleUrl.href); // present-but-broken dependencies fail visibly, never pretend unavailable success
}
export async function prepareRequestV2(value,{moduleUrl=defaultModule}={}){
 identity(value);const gad=await engine(moduleUrl);
 if(!gad)return unavailableV2(value);
 return gad.prepareRequestV2(value);
}
export async function consumeDeliveryV2(value,options,{moduleUrl=defaultModule}={}){
 identity(value);
 if(!options||options.hostType!==hostType||options.hostRef!==value.host_ref)throw new Error('Explicit matching host consumer context required');
 const gad=await engine(moduleUrl);if(!gad)return unavailableV2(value);
 return gad.consumeDeliveryV2(value,options);
}
