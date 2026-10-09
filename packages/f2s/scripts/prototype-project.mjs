import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PATHS = ['single-file', 'maintained-project'];
const STAGES = ['internal', 'v1', 'ninety-plus', 'delivered'];
const DIMENSIONS = ['scope', 'core-loop', 'operation', 'presentation', 'reliability', 'traceability'];
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const nonempty = v => typeof v === 'string' && v.trim().length > 0;
const assert = (v, m) => { if (!v) throw new Error(m); };

function localFile(root, relative) {
  assert(nonempty(relative) && !path.isAbsolute(relative) && !relative.includes(':') &&
    !relative.split(/[\\/]/).some(p => p === '..' || p === ''), 'Unsafe evidence path');
  const target = path.resolve(root, relative);
  assert(fs.existsSync(target) && fs.statSync(target).isFile(), 'Evidence file missing: ' + relative);
  const realRoot = fs.realpathSync(root), realTarget = fs.realpathSync(target);
  const rel = path.relative(realRoot, realTarget);
  assert(rel && !rel.startsWith('..') && !path.isAbsolute(rel), 'Evidence escapes project');
  return realTarget;
}
function evidenceFile(root, item) {
  assert(item && /^[a-f0-9]{64}$/.test(item.sha256), 'Evidence SHA256 required');
  assert(sha(localFile(root, item.file)) === item.sha256, 'Evidence content changed: ' + item.file);
}
export function initialState(name, lifecycle) {
  assert(nonempty(name) && PATHS.includes(lifecycle), 'Name and supported lifecycle required');
  return {
    schema_version: 2, project_name: name, lifecycle, stage: 'internal',
    build: { id: '', implementation_started: false, artifact: null },
    environment: { platform: '', engine: '', engine_version: '', language: '', build_command: '', run_command: '', input: '' },
    evidence: [], checks: Object.fromEntries(DIMENSIONS.map(d => [d, []])),
    issues: [], recognition: { status: 'pending' },
    handoff: { status: 'not-started' },
    limitations: ['Scaffold only; no implementation, playtest, recognition or delivery has occurred.']
  };
}
export function initProject(project, name, lifecycle, apply = false) {
  const target = path.resolve(project);
  const state = initialState(name, lifecycle);
  const names = ['project-entry', 'design-baseline', 'decisions-and-issues', 'verification-and-delivery'];
  const outputs = names.map(n => ({
    file: n + '.md',
    content: fs.readFileSync(path.join(ROOT, 'templates', n + '.md'), 'utf8').replaceAll('{{project_name}}', name)
  }));
  outputs.push({ file: 'project-state.json', content: JSON.stringify(state, null, 2) + '\n' });
  for (const o of outputs) assert(!fs.existsSync(path.join(target, o.file)), 'Refusing overwrite: ' + o.file);
  if (apply) {
    fs.mkdirSync(target, { recursive: true });
    for (const o of outputs) fs.writeFileSync(path.join(target, o.file), o.content, { flag: 'wx', encoding: 'utf8' });
  }
  return { mode: apply ? 'apply' : 'plan', project: target, files: outputs.map(o => o.file), implementation_created: false };
}
export function checkState(project, state) {
  const root = path.resolve(project);
  assert(state?.schema_version === 2, 'Unsupported project state');
  assert(nonempty(state.project_name) && PATHS.includes(state.lifecycle) && STAGES.includes(state.stage), 'Invalid project identity or stage');
  assert(state.build && typeof state.build.implementation_started === 'boolean', 'Build declaration required');
  assert(Array.isArray(state.evidence) && Array.isArray(state.issues) && Array.isArray(state.limitations), 'Evidence, issues and limitations must be arrays');
  const mature = ['ninety-plus', 'delivered'].includes(state.stage);
  const ready = state.stage !== 'internal';
  if (state.lifecycle === 'maintained-project' && (state.build.implementation_started || ready)) {
    for (const key of ['platform', 'engine', 'engine_version', 'language', 'build_command', 'run_command', 'input'])
      assert(nonempty(state.environment?.[key]), 'Formal environment required before implementation: ' + key);
  }
  const evidence = new Map();
  for (const e of state.evidence) {
    assert(nonempty(e.id) && !evidence.has(e.id), 'Unique evidence ID required');
    for (const key of ['build_id', 'environment', 'scenario', 'expected', 'actual', 'operator', 'method'])
      assert(nonempty(e[key]), 'Evidence field required: ' + key);
    assert(['passed', 'failed', 'not-run'].includes(e.result), 'Evidence result invalid');
    evidenceFile(root, e);
    evidence.set(e.id, e);
  }
  const usable = id => {
    const e = evidence.get(id);
    assert(e && e.result === 'passed', 'Passed evidence required: ' + id);
    assert(e.build_id === state.build.id ||
      (e.reuse?.for_build === state.build.id && nonempty(e.reuse.reason) && nonempty(e.reuse.impact_ref)),
      'Evidence does not cover current build: ' + id);
    if (e.build_id !== state.build.id) localFile(root, e.reuse.impact_ref);
    return e;
  };
  for (const issue of state.issues) {
    assert(nonempty(issue.id) && ['bug', 'experience', 'preference', 'request', 'debt', 'unknown'].includes(issue.type), 'Issue identity/type invalid');
    assert(['open', 'closed', 'deferred'].includes(issue.status), 'Issue status invalid');
    if (issue.status === 'closed') {
      assert(nonempty(issue.resolution) && Array.isArray(issue.evidence_ids) && issue.evidence_ids.length > 0, 'Closed issue needs resolution and verification');
      issue.evidence_ids.forEach(usable);
    }
    if (ready) assert(issue.type !== 'bug' || issue.status === 'closed', 'Known bug blocks V1');
    if (mature) assert(!(issue.type === 'experience' && issue.major === true && issue.status !== 'closed'), 'Major experience issue blocks 90+');
  }
  if (ready) {
    assert(state.build.implementation_started && nonempty(state.build.id), 'Real build declaration required');
    evidenceFile(root, state.build.artifact);
    for (const d of DIMENSIONS) {
      const ids = state.checks?.[d];
      assert(Array.isArray(ids) && ids.length > 0, 'Missing quality dimension: ' + d);
      ids.forEach(usable);
    }
    const methods = new Set(Object.values(state.checks).flat().map(id => usable(id).method));
    assert(methods.has('runtime-input') && methods.has('full-loop-play'), 'Actual input and full-loop play evidence required');
    const presentation = state.checks.presentation.map(usable);
    for (const aspect of ['understanding', 'feeling', 'coherence'])
      assert(presentation.some(e => e.aspects?.includes(aspect)), 'Presentation aspect missing: ' + aspect);
  }
  if (mature) {
    const r = state.recognition;
    assert(r?.status === 'recognized' && r.actor === 'user' && r.subject === 'core-gameplay', 'User core gameplay recognition required');
    assert(nonempty(r.quote) && nonempty(r.source_ref) && nonempty(r.recorded_at) && nonempty(r.scope), 'Recognition source, quote and scope required');
    evidenceFile(root, r);
    assert(r.build_id === state.build.id ||
      (r.reuse?.for_build === state.build.id && nonempty(r.reuse.reason) && nonempty(r.reuse.impact_ref)), 'User recognition no longer covers build');
    if (r.build_id !== state.build.id) localFile(root, r.reuse.impact_ref);
    assert(Array.isArray(state.checks['handoff-ready']) && state.checks['handoff-ready'].length > 0, 'Handoff preparation evidence required');
    state.checks['handoff-ready'].forEach(usable);
  }
  if (state.handoff?.status === 'accepted' || state.stage === 'delivered') {
    assert(mature, 'Delivery requires 90+');
    const h = state.handoff;
    assert(h.status === 'accepted' && nonempty(h.receiver) && nonempty(h.source_build), 'Actual receiver and source build required');
    assert(h.source_build === state.build.id, 'Handoff build mismatch');
    const steps = state.lifecycle === 'single-file' ? ['run', 'baseline-review'] : ['build', 'run', 'change', 'regression'];
    for (const s of steps) {
      const e = usable(h.steps?.[s]);
      assert(e.operator === h.receiver, 'Receiving Agent must perform step: ' + s);
      assert(e.method === 'reception-' + s, 'Wrong receiving evidence method: ' + s);
    }
    if (state.lifecycle === 'maintained-project') {
      assert(nonempty(h.change_purpose), 'Actual small change purpose required');
      evidenceFile(root, h.change_diff);
    }
    assert(nonempty(h.next_production_step), 'Next production step required');
  }
  return { structure_passed: true, declared_stage: state.stage, semantic_review: 'required',
    user_recognition_verified: false, actual_play_quality_verified: false,
    note: 'Checks referenced local evidence and declarations; a trusted host must review their meaning and the real user source.' };
}
function args(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i++) {
    assert(argv[i].startsWith('--'), 'Expected named argument');
    const key = argv[i].slice(2);
    assert(['project', 'name', 'path', 'apply', 'state'].includes(key) && !(key in result), 'Unknown or duplicate argument');
    if (key === 'apply') result[key] = true;
    else { assert(argv[i + 1] && !argv[i + 1].startsWith('--'), 'Missing argument value'); result[key] = argv[++i]; }
  }
  return result;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const command = process.argv[2], a = args(process.argv.slice(3));
    assert(a.project, '--project required');
    let result;
    if (command === 'init') result = initProject(a.project, a.name, a.path, a.apply);
    else if (command === 'check-state') {
      assert(!a.apply, 'check-state is read-only');
      const source = localFile(path.resolve(a.project), a.state || 'project-state.json');
      result = checkState(a.project, JSON.parse(fs.readFileSync(source, 'utf8')));
    } else throw new Error('Use init or check-state');
    process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  } catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 2; }
}
