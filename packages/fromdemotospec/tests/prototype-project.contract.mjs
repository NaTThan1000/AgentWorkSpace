import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { initialState, initProject, checkState } from '../scripts/prototype-project.mjs';

const script = fileURLToPath(new URL('../scripts/prototype-project.mjs', import.meta.url));
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function fixture(lifecycle = 'single-file') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'f2s-state-contract-'));
  const file = (name, content = 'SYNTHETIC CONTRACT FIXTURE; NOT A GAME OR REAL USER ACCEPTANCE.\n') => {
    fs.writeFileSync(path.join(root, name), content);
    return { file: name, sha256: hash(path.join(root, name)) };
  };
  const state = initialState('Synthetic contract fixture', lifecycle);
  state.build = { id: 'fixture-b1', implementation_started: true, artifact: file('build.txt') };
  state.environment = Object.fromEntries(['platform', 'engine', 'engine_version', 'language', 'build_command', 'run_command', 'input'].map(k => [k, 'fixture-only']));
  state.stage = 'v1';
  function evidence(id, method, extra = {}) {
    const e = { id, build_id: state.build.id, environment: 'synthetic-only', scenario: 'fixture',
      expected: 'fixture', actual: 'fixture', operator: 'fixture-maker', method, result: 'passed', ...file(id + '.txt'), ...extra };
    state.evidence.push(e);
    return id;
  }
  const run = evidence('runtime', 'runtime-input');
  const loop = evidence('loop', 'full-loop-play');
  const visual = evidence('visual', 'runtime-review', { aspects: ['understanding', 'feeling', 'coherence'] });
  for (const d of Object.keys(state.checks)) state.checks[d] = [run];
  state.checks['core-loop'] = [loop];
  state.checks.presentation = [visual];
  const mature = () => {
    state.stage = 'ninety-plus';
    state.recognition = { status: 'recognized', actor: 'user', subject: 'core-gameplay',
      quote: 'SYNTHETIC test value, no real recognition', source_ref: 'fixture-only', recorded_at: 'fixture',
      scope: 'fixture-only', build_id: state.build.id, ...file('recognition.txt') };
    state.checks['handoff-ready'] = [evidence('prepared', 'document-review')];
  };
  const deliver = () => {
    mature(); state.stage = 'delivered';
    state.handoff = { status: 'accepted', receiver: 'fixture-receiver', source_build: state.build.id,
      steps: {}, next_production_step: 'fixture task, not actually performed' };
    const steps = lifecycle === 'single-file' ? ['run', 'baseline-review'] : ['build', 'run', 'change', 'regression'];
    for (const s of steps) state.handoff.steps[s] = evidence('receive-' + s, 'reception-' + s, { operator: 'fixture-receiver' });
    if (lifecycle === 'maintained-project') {
      state.handoff.change_purpose = 'synthetic regression fixture';
      state.handoff.change_diff = file('change.diff');
    }
  };
  return { root, state, evidence, file, mature, deliver, dispose: () => fs.rmSync(root, { recursive: true, force: true }) };
}
function scenario(name, fn, lifecycle) {
  test(name, () => { const f = fixture(lifecycle); try { fn(f); } finally { f.dispose(); } });
}
test('CLI init plans without writing, creates documents and refuses overwrite', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'f2s-init-contract-'));
  try {
    const project = path.join(root, 'project');
    const call = (...args) => spawnSync(process.execPath, [script, ...args], { encoding: 'utf8' });
    const plan = call('init', '--project', project, '--name', 'Fixture', '--path', 'single-file');
    assert.equal(plan.status, 0); assert.equal(fs.existsSync(project), false);
    const apply = call('init', '--project', project, '--name', 'Fixture', '--path', 'single-file', '--apply');
    assert.equal(apply.status, 0, apply.stderr);
    assert.equal(fs.readdirSync(project).length, 5);
    const before = hash(path.join(project, 'design-baseline.md'));
    assert.equal(call('check-state', '--project', project).status, 0);
    const again = call('init', '--project', project, '--name', 'Fixture', '--path', 'single-file', '--apply');
    assert.equal(again.status, 2);
    assert.equal(hash(path.join(project, 'design-baseline.md')), before);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
scenario('V1 declaration passes without requiring user recognition or preview approval', f => {
  const result = checkState(f.root, f.state);
  assert.equal(result.structure_passed, true);
  assert.equal(result.user_recognition_verified, false);
  assert.equal(result.actual_play_quality_verified, false);
});
scenario('unrun build cannot be V1', f => {
  f.state.build.implementation_started = false;
  assert.throws(() => checkState(f.root, f.state), /Real build/);
});
scenario('known bug blocks V1 even when marked deferred', f => {
  f.state.issues.push({ id: 'b1', type: 'bug', status: 'deferred' });
  assert.throws(() => checkState(f.root, f.state), /Known bug/);
});
scenario('closing bug without recovery evidence fails', f => {
  f.state.issues.push({ id: 'b1', type: 'bug', status: 'closed', resolution: 'claimed fixed', evidence_ids: [] });
  assert.throws(() => checkState(f.root, f.state), /resolution and verification/);
});
scenario('simulations cannot stand in for actual input and full-loop play', f => {
  f.state.evidence.forEach(e => e.method = 'simulation');
  assert.throws(() => checkState(f.root, f.state), /Actual input/);
});
scenario('presentation must cover feeling as well as understanding', f => {
  f.state.evidence.find(e => e.id === 'visual').aspects = ['understanding', 'coherence'];
  assert.throws(() => checkState(f.root, f.state), /feeling/);
});
scenario('missing evidence file fails', f => {
  fs.unlinkSync(path.join(f.root, 'runtime.txt'));
  assert.throws(() => checkState(f.root, f.state), /missing/);
});
scenario('changed evidence bytes fail', f => {
  fs.appendFileSync(path.join(f.root, 'runtime.txt'), 'changed');
  assert.throws(() => checkState(f.root, f.state), /content changed/);
});
scenario('path traversal fails', f => {
  f.state.evidence[0].file = '../outside.txt';
  assert.throws(() => checkState(f.root, f.state), /Unsafe/);
});
scenario('stale build evidence fails without impact review', f => {
  f.state.evidence[0].build_id = 'old';
  assert.throws(() => checkState(f.root, f.state), /current build/);
});
scenario('explicit valid reuse allows unaffected evidence', f => {
  f.state.evidence[0].build_id = 'old';
  f.file('impact.md');
  f.state.evidence[0].reuse = { for_build: f.state.build.id, reason: 'fixture unaffected', impact_ref: 'impact.md' };
  assert.equal(checkState(f.root, f.state).structure_passed, true);
});
scenario('ninety-plus requires actual user-source declaration', f => {
  f.state.stage = 'ninety-plus';
  assert.throws(() => checkState(f.root, f.state), /User core gameplay/);
});
scenario('Agent recognition cannot replace user', f => {
  f.mature(); f.state.recognition.actor = 'agent';
  assert.throws(() => checkState(f.root, f.state), /User core gameplay/);
});
scenario('visual approval cannot replace gameplay approval', f => {
  f.mature(); f.state.recognition.subject = 'presentation';
  assert.throws(() => checkState(f.root, f.state), /User core gameplay/);
});
scenario('proposed recognition is not accepted recognition', f => {
  f.mature(); f.state.recognition.status = 'proposed';
  assert.throws(() => checkState(f.root, f.state), /User core gameplay/);
});
scenario('changed core requires current recognition coverage', f => {
  f.mature(); f.state.recognition.build_id = 'old';
  assert.throws(() => checkState(f.root, f.state), /no longer covers/);
});
scenario('ninety-plus requires major experience issues closed', f => {
  f.mature(); f.state.issues.push({ id: 'x1', type: 'experience', major: true, status: 'open' });
  assert.throws(() => checkState(f.root, f.state), /Major experience/);
});
scenario('maintained implementation cannot start without formal environment', f => {
  f.state.stage = 'internal'; f.state.environment.engine = '';
  assert.throws(() => checkState(f.root, f.state), /engine/);
}, 'maintained-project');
scenario('maintained scaffold can exist before engine choice, without implementation claims', f => {
  const state = initialState('fixture', 'maintained-project');
  assert.equal(checkState(f.root, state).structure_passed, true);
}, 'maintained-project');
scenario('ninety-plus does not require receiving step prematurely', f => {
  f.mature(); assert.equal(checkState(f.root, f.state).structure_passed, true);
}, 'maintained-project');
scenario('single-file delivery permits engine reconstruction to remain a production task', f => {
  f.deliver(); f.state.handoff.next_production_step = 'Select formal engine and reproduce baseline';
  assert.equal(checkState(f.root, f.state).structure_passed, true);
});
scenario('maintained delivery requires actual receiver small change and regression declarations', f => {
  f.deliver(); assert.equal(checkState(f.root, f.state).structure_passed, true);
  delete f.state.handoff.steps.change;
  assert.throws(() => checkState(f.root, f.state), /Passed evidence/);
}, 'maintained-project');
scenario('receiver identity must match receiving evidence', f => {
  f.deliver(); f.state.handoff.receiver = 'someone-else';
  assert.throws(() => checkState(f.root, f.state), /Receiving Agent/);
}, 'maintained-project');
scenario('handoff accepted cannot be claimed before maturity', f => {
  f.state.handoff.status = 'accepted';
  assert.throws(() => checkState(f.root, f.state), /Delivery requires/);
});
