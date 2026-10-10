import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {prepareRequestV2,prepareDeliveryV2,consumeDeliveryV2,validateDeliveryV2} from '../scripts/adapter-v2.mjs';
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'game-analysis-decision-delivery-v2-'));
try{
 const text='建议先缩小共享资源约束。此为合成合同测试，不是用户玩法认可。\n';
 fs.writeFileSync(path.join(dir,'report.md'),text);
 const body={path:'report.md',sha256:crypto.createHash('sha256').update(text).digest('hex'),format:'markdown'};
 const common={schema_version:2,request_id:'ARQ-v2-test',adapter_id:'fromdemotospec-adapter',host_ref:'fromdemotospec:test',host_write_target_ref:'fromdemotospec:test#analysis'};
 const request={...common,created_at:'2026-09-08T00:00:00Z',intent:'analyze',goal:'检查共享资源',allowed_sources:['project'],input_refs:[],constraints:[],budget:{time_minutes:10,tool_calls:4}};
 assert.deepEqual(prepareRequestV2(request),request);
 assert.throws(()=>prepareRequestV2({...request,intent:'decide'}),/decision question/);
 assert.throws(()=>prepareRequestV2({...request,host_ref:'knowledge:wrong'}),/namespace/);
 assert.throws(()=>prepareRequestV2({...request,schema_version:3}));
 const intake={...common,delivery_id:'HOF-v2-test',endpoint:'analysis_report',result_ref:'analysis:test',result_status:'complete',action_class:'analysis_only',body,source_refs:['project:test'],limitations:['合成测试']};
 const delivery=prepareDeliveryV2(intake,{artifactRoot:dir});
 const options={hostType:'fromdemotospec',hostRef:'fromdemotospec:test',artifactRoot:dir};
 assert.equal(delivery.next_action,'consume_analysis');assert.equal(delivery.human_review.required,false);
 const consumed=consumeDeliveryV2(delivery,options);
 assert.equal(consumed.body,text);assert.equal(consumed.executed,false);assert.equal(consumed.formal_decision_written,false);
 assert.deepEqual(validateDeliveryV2({...delivery,human_review:{reason:'none',owner:'host_user',required:false}}),[]);
 assert.throws(()=>consumeDeliveryV2(delivery,{...options,hostRef:'fromdemotospec:other'}),/identity/);
 assert.throws(()=>consumeDeliveryV2({...delivery,next_action:'producer_decision'},options),/routing/);
 assert.throws(()=>prepareDeliveryV2({...intake,action_class:'important_decision'},{artifactRoot:dir}),/Analysis report/);
 const decision=prepareDeliveryV2({...intake,endpoint:'decision_packet',result_ref:'decision:test',result_status:'proposed',action_class:'important_decision'},{artifactRoot:dir});
 assert.equal(decision.next_action,'producer_decision');assert.equal(decision.human_review.required,true);
 assert.throws(()=>consumeDeliveryV2({...decision,human_review:{required:false,owner:'host_user',reason:'none'}},options),/routing/);
 for(const [status,action] of [['needs_evidence','collect_evidence'],['rejected','record_terminal_result']]){
  const d=prepareDeliveryV2({...intake,endpoint:'decision_packet',result_ref:'decision:test',result_status:status,action_class:'important_decision'},{artifactRoot:dir});
  assert.equal(d.next_action,action);assert.equal(d.human_review.required,false);
 }
 const experiment={...intake,endpoint:'experiment_plan',result_ref:'experiment:test',result_status:'proposed',action_class:'read_only_verification'};
 assert.equal(prepareDeliveryV2(experiment,{artifactRoot:dir}).human_review.required,false);
 const auth=prepareDeliveryV2({...experiment,action_class:'authorized_host_verification',authorization_ref:'fromdemotospec:test#user-scope'},{artifactRoot:dir});
 assert.throws(()=>consumeDeliveryV2(auth,options),/authorization/);
 assert.equal(consumeDeliveryV2(auth,{...options,authorizedRefs:['fromdemotospec:test#user-scope']}).next_action,'perform_host_authorized_verification');
 assert.equal(prepareDeliveryV2({...experiment,action_class:'external_or_new_authority'},{artifactRoot:dir}).human_review.required,true);
 assert.throws(()=>prepareDeliveryV2({...intake,body:{...body,path:'../escape.md'}},{artifactRoot:dir}),/escape|relative|outside/i);
 fs.writeFileSync(path.join(dir,'report.md'),'tampered');assert.throws(()=>consumeDeliveryV2(delivery,options),/hash/);
 console.log('Adapter v2 behavioral contracts PASS; does not verify recommendation quality or confer authority');
}finally{fs.unlinkSync(path.join(dir,'report.md'));fs.rmdirSync(dir);}
