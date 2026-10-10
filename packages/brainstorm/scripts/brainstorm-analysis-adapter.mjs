import {prepareRequestV2,consumeDeliveryV2,unavailableV2} from './game-analysis-decision-v2-binding.mjs';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const adapterId = 'brainstorm-adapter';

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function exactKeys(value, required, optional = []) {
  const actual = Object.keys(value ?? {}).sort();
  const allowed = [...required, ...optional].sort();
  return {
    missing: required.filter((key) => !actual.includes(key)),
    unknown: actual.filter((key) => !allowed.includes(key))
  };
}

function commonErrors(value, required, optional = []) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return ['$: object is required'];
  const errors = [];
  const keys = exactKeys(value, required, optional);
  for (const key of keys.missing) errors.push(`$.${key}: is required`);
  for (const key of keys.unknown) errors.push(`$.${key}: unknown field`);
  if (value.schema_version !== 1) errors.push('$.schema_version: must equal 1');
  if (!/^ARQ-[A-Za-z0-9][A-Za-z0-9._-]{2,63}$/.test(value.request_id ?? '')) errors.push('$.request_id: invalid ARQ id');
  return errors;
}

function validDateTime(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

function validateProducerDecision(value) {
  const required = [
    'schema_version', 'receipt_id', 'request_id', 'session_ref', 'decision_packet_ref', 'action',
    'decision_id', 'decider', 'producer_ref', 'producer_confirmed', 'host_record_ref',
    'host_record_confirmed', 'recorded_at'
  ];
  const errors = commonErrors(value, required);
  if (!value || typeof value !== 'object' || Array.isArray(value)) return errors;
  if (!/^HDR-[A-Za-z0-9][A-Za-z0-9._-]{2,63}$/.test(value.receipt_id ?? '')) errors.push('$.receipt_id: invalid HDR id');
  if (!/^brainstorm:[^\s#]+$/.test(value.session_ref ?? '')) errors.push('$.session_ref: invalid brainstorm session reference');
  if (!value.decision_packet_ref?.startsWith('decision:')) errors.push('$.decision_packet_ref: must use decision: namespace');
  if (!['accepted', 'rejected', 'needs_evidence'].includes(value.action)) errors.push('$.action: unsupported producer action');
  if (!/^DEC-[0-9]{3,}$/.test(value.decision_id ?? '')) errors.push('$.decision_id: invalid Brainstorm Decision ID');
  if (!['user', 'joint'].includes(value.decider)) errors.push('$.decider: formal Brainstorm decision requires user or joint');
  if (!value.producer_ref?.startsWith('producer:')) errors.push('$.producer_ref: must use producer: namespace');
  if (value.producer_confirmed !== true) errors.push('$.producer_confirmed: explicit producer confirmation is required');
  if (value.host_record_ref !== `${value.session_ref}#${value.decision_id}`) errors.push('$.host_record_ref: must reference the exact Brainstorm Decision');
  if (value.host_record_confirmed !== true) errors.push('$.host_record_confirmed: caller must confirm the formal Brainstorm record exists');
  if (!validDateTime(value.recorded_at)) errors.push('$.recorded_at: valid date-time is required');
  return errors;
}

function prepareHostDecisionReceipt(value) {
  const errors = validateProducerDecision(value);
  if (errors.length > 0) throw new Error(`Brainstorm producer decision rejected:\n${errors.join('\n')}`);
  return {
    schema_version: 1,
    receipt_id: value.receipt_id,
    request_id: value.request_id,
    adapter_id: adapterId,
    host_ref: value.session_ref,
    decision_packet_ref: value.decision_packet_ref,
    observed_action: value.action,
    producer_ref: value.producer_ref,
    host_record_ref: value.host_record_ref,
    recorded_at: value.recorded_at,
    recorded_by: 'host',
    game_analysis_decision_consumption: 'read_only_reference'
  };
}

function argumentValue(args, name) {
  const index = args.indexOf(name);
  if (index < 0 || !args[index + 1]) throw new Error(`Missing ${name}`);
  return args[index + 1];
}

async function runCli() {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'status') {
    process.stdout.write(JSON.stringify({schema_version:2,adapter_id:adapterId,status:'binding_ready',
      request_contract:'GameAnalysisDecision v2',receipt_contract:'HostDecisionReceipt v1',
      commands:['prepare-request','consume-delivery','prepare-unavailable','prepare-host-decision'],
      analysis_executed:false,permissions:{host_write:false,accept_decision:false,run_experiment:false}},null,2)+'\n');
    return;
  }
  const input=readJson(path.resolve(argumentValue(args,'--input')));
  let result;
  if(command==='prepare-host-decision') result=prepareHostDecisionReceipt(input);
  else if(command==='prepare-request') result=await prepareRequestV2(input);
  else if(command==='prepare-unavailable') result=unavailableV2(input);
  else if(command==='consume-delivery') result=await consumeDeliveryV2(input,readJson(path.resolve(argumentValue(args,'--consumer'))));
  else throw new Error('Usage: status | prepare-request --input <json> | consume-delivery --input <json> --consumer <json> | prepare-unavailable --input <json> | prepare-host-decision --input <json>');
  process.stdout.write(JSON.stringify(result,null,2)+'\n');
}
if(process.argv[1]&&path.resolve(process.argv[1])===scriptPath){
 try{await runCli();}catch(error){process.stderr.write(error.message+'\n');process.exitCode=1;}
}
export {prepareRequestV2,consumeDeliveryV2,unavailableV2,prepareHostDecisionReceipt,validateProducerDecision};
