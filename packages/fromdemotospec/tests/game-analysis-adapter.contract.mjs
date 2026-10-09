import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { prepareAdapterIntake, prepareHostDecisionReceipt, prepareUnavailableFallback, validateF2sRequest, validateProducerDecision } from '../scripts/fromdemotospec-analysis-adapter.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const adapterRoot = path.join(root, 'adapters', 'game-analysis-decision');
const examples = path.join(root, 'examples', 'game-analysis-decision');

function readJson(filePath) { return JSON.parse(fs.readFileSync(filePath, 'utf8')); }
function assert(condition, message) { if (!condition) throw new Error(message); }

for (const schemaName of ['fromdemotospec-analysis-request.schema.json', 'fromdemotospec-producer-decision.schema.json']) {
  const schema = readJson(path.join(adapterRoot, schemaName));
  assert(schema.type === 'object' && schema.additionalProperties === false, `${schemaName}: root contract must be closed`);
}

const contract = readJson(path.join(adapterRoot, 'contract.json'));
assert(contract.adapter_id === 'f2s-adapter' && contract.status === 'ready', 'F2S adapter identity drifted.');
assert(contract.external_contract.revision === 'ff66c413f3b623379f81ffbb50bf701876eec34f', 'External adapter revision must be explicitly pinned to the decision-rationale-review revision.');
assert(contract.ownership.formal_decision_owner === 'f2s_host' && contract.ownership.accept_decision === false, 'F2S fact ownership or producer gate drifted.');
assert(contract.commands.legacy_role === 'lead_designer_agent', 'Legacy command must name the Agent role, not the producer.');
assert(contract.compatibility.legacy_sunset === '2026-09-30' && contract.compatibility.legacy_warning_code === 'AD008_LEGACY_COMMAND', 'AD-008 legacy retirement policy drifted.');
assert(contract.compatibility.gad_unavailable === 'continue_f2s_normal_flow' && contract.compatibility.automatic_knowledge_expert_fallback === false, 'GAD-unavailable fallback must remain host-owned and expert-free.');

const request = readJson(path.join(examples, 'f2s-request.json'));
const intake = prepareAdapterIntake(request);
assert(intake.adapter_id === 'f2s-adapter' && intake.intent === 'decide', 'New request command mapping drifted.');
assert(intake.host_ref.startsWith('f2s:') && intake.host_write_target_ref.startsWith('f2s:'), 'F2S namespace was lost.');
assert(!Object.hasOwn(intake, 'legacy_command'), 'New command must not be marked as legacy.');

const legacy = readJson(path.join(examples, 'legacy-request.json'));
const legacyIntake = prepareAdapterIntake(legacy);
assert(legacyIntake.legacy_command === 'lead_designer_takeover' && legacyIntake.requester_role === 'agent', 'Legacy command must remain an Agent request-only compatibility path.');

const unavailable = prepareUnavailableFallback(request);
assert(unavailable.gad_status === 'unavailable' && unavailable.host_action === 'continue_f2s_normal_flow', 'GAD unavailability must return to the F2S normal flow.');
assert(unavailable.automatic_expert_fallback === false && unavailable.permissions.host_write === false, 'Fallback must not invoke Knowledge experts or write F2S state.');

const missingQuestion = structuredClone(request);
delete missingQuestion.decision_question;
assert(validateF2sRequest(missingQuestion).some((error) => error.includes('decision_question')), 'Decide intent without a real question must fail.');

const foreignTarget = structuredClone(request);
foreignTarget.host_write_target_ref = 'brainstorm:DEC-001';
assert(validateF2sRequest(foreignTarget).some((error) => error.includes('host_write_target_ref')), 'Foreign host target must fail.');

const unknownField = structuredClone(request);
unknownField.auto_write_demo = true;
assert(validateF2sRequest(unknownField).some((error) => error.includes('unknown field')), 'Unknown auto-write field must fail closed.');

const producerDecision = readJson(path.join(examples, 'producer-decision.json'));
const receipt = prepareHostDecisionReceipt(producerDecision);
assert(receipt.recorded_by === 'host' && receipt.gad_consumption === 'read_only_reference', 'Decision receipt must remain a read-only host fact.');

const unconfirmed = structuredClone(producerDecision);
unconfirmed.producer_confirmed = false;
assert(validateProducerDecision(unconfirmed).some((error) => error.includes('explicit producer confirmation')), 'Unconfirmed Agent action must not become a producer decision.');

const missingHostRecord = structuredClone(producerDecision);
missingHostRecord.host_record_ref = 'decision:DCP-f2s-adapter-demo';
assert(validateProducerDecision(missingHostRecord).some((error) => error.includes('already exist in F2S')), 'Receipt requires a prior F2S formal record.');

const unconfirmedHostRecord = structuredClone(producerDecision);
unconfirmedHostRecord.host_record_confirmed = false;
assert(validateProducerDecision(unconfirmedHostRecord).some((error) => error.includes('caller must confirm')), 'Receipt requires explicit confirmation that the F2S record exists.');

assert(validateF2sRequest(null).length > 0 && validateProducerDecision([]).length > 0, 'Non-object inputs must fail closed without crashing.');

process.stdout.write('F2S AD-005/008 game-analysis adapter contract: PASS (2 request paths, 1 fallback, 1 producer receipt, 7 negative gates)\n');

assert(contract.request_policy.per_request_confirmation === false && contract.request_policy.formal_product_decision === 'user' && contract.request_policy.automatic_knowledge_ingest === false, 'Autonomous analysis must preserve user adoption and no-ingest boundaries');
const autonomousRequest = structuredClone(request);
autonomousRequest.requester_role = 'agent';
autonomousRequest.source_policy = 'project_and_knowledge';
const autonomousIntake = prepareAdapterIntake(autonomousRequest);
assert(autonomousIntake.requester_role === 'agent' && autonomousIntake.source_policy === 'project_and_knowledge', 'Agent requests must work without per-request producer approval');
assert(!Object.hasOwn(autonomousIntake, 'producer_confirmed'), 'Request must not pretend producer adoption');
process.stdout.write('F2S v2 autonomous request boundary: PASS\n');
