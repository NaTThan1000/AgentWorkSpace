import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

function finite(value, label, {min=0, integer=false}={}) {
 if(typeof value!=='number'||!Number.isFinite(value)||value<min||(integer&&!Number.isInteger(value))) throw new Error(label+' must be a finite '+(integer?'integer':'number')+' >= '+min);
 return value;
}
function exact(value, keys) {
 if(!value||typeof value!=='object'||Array.isArray(value)) throw new Error('Expected an object');
 for(const k of Object.keys(value)) if(!keys.includes(k)) throw new Error('Unknown field: '+k);
 for(const k of keys) if(!(k in value)) throw new Error('Missing field: '+k);
}
export function capacity(input) {
 exact(input,['capacity','shared','demands']);
 finite(input.capacity,'capacity');
 if(typeof input.shared!=='boolean') throw new Error('shared must be explicit; do not assume resource competition');
 if(!Array.isArray(input.demands)||input.demands.length===0) throw new Error('demands must be non-empty');
 const ids=new Set();
 const rows=input.demands.map(d=>{
  exact(d,['id','demand_per_period','yield_per_unit_period']);
  if(typeof d.id!=='string'||!d.id.trim()||ids.has(d.id)) throw new Error('Unique nonempty demand id required');
  ids.add(d.id);finite(d.demand_per_period,'demand_per_period');finite(d.yield_per_unit_period,'yield_per_unit_period',{min:Number.MIN_VALUE});
  return {...d,required_units:d.demand_per_period/d.yield_per_unit_period};
 });
 const total=rows.reduce((n,r)=>n+r.required_units,0);
 if(!Number.isFinite(total)) throw new Error('Required capacity overflow');
 return {rows,required_units:input.shared?total:Math.max(...rows.map(r=>r.required_units)),feasible:input.shared?total<=input.capacity:rows.every(r=>r.required_units<=input.capacity),
  assumption:input.shared?'All rows compete for the same divisible steady-state capacity.':'Each row has its own independent capacity of the supplied size.',
  limitation:'Common time units required. Does not model discrete plots, buffers, switching, stochastic yields, or player experience.'};
}
export function responseWindow(input) {
 exact(input,['first_visible_ms','impact_ms','input_and_action_ms']);
 for(const k of Object.keys(input)) finite(input[k],k);
 if(input.impact_ms<input.first_visible_ms) throw new Error('Impact precedes first visibility; no forward response window');
 const visible_window_ms=input.impact_ms-input.first_visible_ms;
 return {visible_window_ms,decision_window_ms:visible_window_ms-input.input_and_action_ms,
  limitation:'Remaining time is not proof of human readability or reaction success; inspect actual presentation and input.'};
}
export function proportions(input) {
 exact(input,['strata']);
 if(!Array.isArray(input.strata)||!input.strata.length) throw new Error('strata must be non-empty');
 let wins=0,trials=0;
 const rows=input.strata.map(r=>{
  exact(r,['id','wins','trials']);
  if(typeof r.id!=='string'||!r.id.trim()) throw new Error('Stratum id required');
  finite(r.wins,'wins',{integer:true});finite(r.trials,'trials',{min:1,integer:true});
  if(r.wins>r.trials) throw new Error('wins exceeds trials');
  wins+=r.wins;trials+=r.trials;
  const p=r.wins/r.trials,z=1.959963984540054,z2=z*z,den=1+z2/r.trials;
  const center=(p+z2/(2*r.trials))/den;
  const half=z*Math.sqrt(p*(1-p)/r.trials+z2/(4*r.trials*r.trials))/den;
  return {...r,rate:p,wilson95:[Math.max(0,center-half),Math.min(1,center+half)]};
 });
 if(new Set(rows.map(r=>r.id)).size!==rows.length) throw new Error('Duplicate stratum');
 if(!Number.isSafeInteger(wins)||!Number.isSafeInteger(trials)) throw new Error('Counts exceed safe integer precision');
 return {rows,wins,trials,weighted_rate:wins/trials,
  limitation:'Wilson intervals assume binomial sampling. Repeated players, selection, version or matchup confounding are not corrected; an aggregate is not a causal comparison.'};
}
export function continueValue(input) {
 exact(input,['current_loot','additional_loot','failure_probability','retained_on_failure']);
 finite(input.current_loot,'current_loot');finite(input.additional_loot,'additional_loot');finite(input.failure_probability,'failure_probability');finite(input.retained_on_failure,'retained_on_failure');
 if(input.failure_probability>1) throw new Error('failure_probability must be <= 1');
 const expected=(1-input.failure_probability)*(input.current_loot+input.additional_loot)+input.failure_probability*input.retained_on_failure;
 if(!Number.isFinite(expected)) throw new Error('Expected value overflow');
 return {expected_final_loot:expected,delta_vs_safe_exit:expected-input.current_loot,
 limitation:'Risk-neutral single-step expectation under the supplied probabilities; excludes time, future options and subjective tension.'};
}
export const calculations={capacity,window:responseWindow,proportions,'continue-value':continueValue};
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href) {
 try {
  const [op,file,...extra]=process.argv.slice(2);
  if(!calculations[op]||!file||extra.length) throw new Error('Usage: node scripts/analysis-math.mjs <capacity|window|proportions|continue-value> <input.json>');
  console.log(JSON.stringify(calculations[op](JSON.parse(fs.readFileSync(file,'utf8'))),null,2));
 } catch(e) {console.error(e.message);process.exitCode=2;}
}
