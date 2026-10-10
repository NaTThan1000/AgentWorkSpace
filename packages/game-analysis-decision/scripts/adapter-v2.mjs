import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {readJson,validateSchema,assertClosedObjectSchemas} from './validate-contracts.mjs';
import {containedPath} from './learning-cli.mjs';
const root=path.resolve(import.meta.dirname,'..');
const schema=readJson(path.join(root,'adapters/v2/contract.schema.json'));
assertClosedObjectSchemas(schema);
const prefixes={'standalone-adapter':'standalone:','f2s-adapter':'f2s:','brainstorm-adapter':'brainstorm:','knowledge-adapter':'knowledge:'};
const endpoints={analysis_report:{prefix:'analysis:',statuses:['draft','complete','needs_evidence']},decision_packet:{prefix:'decision:',statuses:['proposed','rejected','needs_evidence','superseded']},experiment_plan:{prefix:'experiment:',statuses:['proposed','needs_evidence','cancelled','superseded']}};
function validate(value,kind){
 const errors=validateSchema(value,schema.$defs[kind],schema);
 if(errors.length)return errors;
 const prefix=prefixes[value.adapter_id];
 if(!value.host_ref.startsWith(prefix)||!value.host_write_target_ref.startsWith(prefix))errors.push('Host namespace mismatch');
 if(value.adapter_id==='brainstorm-adapter'&&!value.host_write_target_ref.startsWith(value.host_ref+'#'))errors.push('Brainstorm target must stay in the same session');
 if(kind==='request'){
  if(value.intent==='decide'&&!value.decision_question?.trim())errors.push('Decide requires a real decision question');
  if(value.intent!=='decide'&&value.decision_question)errors.push('A decision question cannot be hidden in ordinary analysis');
 }else{
  const rule=endpoints[value.endpoint];
  if(!value.result_ref.startsWith(rule.prefix)||!rule.statuses.includes(value.result_status))errors.push('Endpoint identity or status mismatch');
  if(value.endpoint==='decision_packet'&&value.action_class!=='important_decision')errors.push('Decision cannot bypass producer gate');
  if(value.endpoint==='analysis_report'&&value.action_class!=='analysis_only')errors.push('Analysis report cannot grant experiment or decision action');
  if(value.endpoint==='experiment_plan'&&!['read_only_verification','authorized_host_verification','external_or_new_authority'].includes(value.action_class))errors.push('Experiment requires an explicit verification action class');
  if(value.action_class==='authorized_host_verification'&&!value.authorization_ref?.startsWith(prefix))errors.push('Existing host authorization reference required');
  if(value.authorization_ref&&value.action_class!=='authorized_host_verification')errors.push('Unused authorization ref is not permitted');
  try{containedPath(root,value.body.path);}catch(e){errors.push(e.message);}
  if(kind==='delivery'){
   const expected=route(value);
   if(value.delivery_status!==expected.delivery_status||value.next_action!==expected.next_action||['required','owner','reason'].some(k=>value.human_review[k]!==expected.human_review[k]))errors.push('Delivery routing or human gate was altered');
  }
 }
 return errors;
}
export const validateRequestV2=value=>validate(value,'request');
export const validateIntakeV2=value=>validate(value,'intake');
export const validateDeliveryV2=value=>validate(value,'delivery');
function requireValid(value,kind){const errors=validate(value,kind);if(errors.length)throw new Error('GAD v2 '+kind+' rejected: '+errors.join('; '));}
export function prepareRequestV2(value){requireValid(value,'request');return structuredClone(value);}
function route(value){
 let delivery_status='ready_for_host',next_action,reason='none';
 if(['draft','needs_evidence'].includes(value.result_status)){delivery_status='needs_evidence';next_action='collect_evidence';}
 else if(['rejected','cancelled','superseded'].includes(value.result_status)){delivery_status='terminal';next_action='record_terminal_result';}
 else switch(value.action_class){
  case 'analysis_only':next_action='consume_analysis';break;
  case 'read_only_verification':next_action='perform_read_only_verification';break;
  case 'authorized_host_verification':next_action='perform_host_authorized_verification';break;
  case 'important_decision':next_action='producer_decision';reason='important_decision';break;
  case 'external_or_new_authority':next_action='request_authorization';reason='new_authority';break;
 }
 return {delivery_status,next_action,human_review:{required:reason!=='none',owner:'host_user',reason}};
}
export function readBodyV2(body,{artifactRoot=root}={}){
 const filename=containedPath(artifactRoot,body.path),bytes=fs.readFileSync(filename);
 if(crypto.createHash('sha256').update(bytes).digest('hex')!==body.sha256)throw new Error('Presentation body hash mismatch');
 const content=bytes.toString('utf8');if(!content.trim())throw new Error('Presentation body is empty');
 return content;
}
export function prepareDeliveryV2(value,{artifactRoot=root}={}){
 requireValid(value,'intake');readBodyV2(value.body,{artifactRoot});
 const result={...structuredClone(value),...route(value),permissions:{host_write:false,accept_decision:false,run_experiment:false}};
 requireValid(result,'delivery');return result;
}
export function consumeDeliveryV2(value,{hostType,hostRef,artifactRoot=root,authorizedRefs=[]}={}){
 requireValid(value,'delivery');
 if(value.adapter_id!==hostType+'-adapter'||value.host_ref!==hostRef)throw new Error('Consumer identity mismatch');
 const content=readBodyV2(value.body,{artifactRoot});
 if(value.next_action==='perform_host_authorized_verification'&&!authorizedRefs.includes(value.authorization_ref))throw new Error('Consumer cannot confirm referenced existing authorization');
 return {schema_version:2,request_id:value.request_id,host_ref:hostRef,next_action:value.next_action,requires_user_decision:value.human_review.required,body:content,body_sha256:value.body.sha256,source_refs:value.source_refs,limitations:value.limitations,executed:false,formal_decision_written:false,
  boundary:'Read-only consumption; user decision and actual execution remain owned by host. The returned body is the original verified content, not a second report.'};
}
