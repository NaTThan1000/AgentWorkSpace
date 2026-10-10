import itertools,json,subprocess,sys,tempfile,unittest,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import workspace as w
import compatibility as c
NEW=['skills','game-analysis-decision','game-presentation','prototype-assets']
class OptionalBindings(unittest.TestCase):
 def command(self,args,cwd,ok=True):
  r=subprocess.run(args,cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
  if ok:self.assertEqual(0,r.returncode,r.stdout[-1500:]+r.stderr[-1500:])
  return r
 def test_all_new_package_dependency_combinations(self):
  with tempfile.TemporaryDirectory(prefix='aws-combinations-') as t:
   cat=w.catalog(ROOT)
   for n in range(5):
    for selected in itertools.combinations(NEW,n):
     report=c.audit(cat,Path(t),list(selected));self.assertTrue(report['ready']);self.assertEqual([],report['required'])
 def test_real_asset_import_fromdemotospec_and_offline_verification(self):
  import shutil
  shell=shutil.which('pwsh') or shutil.which('powershell');self.assertIsNotNone(shell)
  with tempfile.TemporaryDirectory(prefix='aws-fromdemotospec-assets-') as t:
   target=Path(t)/'host';w.install(ROOT,target,'init',['fromdemotospec','prototype-assets'],True)
   fromdemotospec=target/'modules/fromdemotospec';assets=target/'modules/prototype-assets';project=Path(t)/'project';project.mkdir()
   asset=json.loads((assets/'catalog/assets.json').read_text(encoding='utf-8'))['assets'][0]
   selection={'schema_version':1,'prototype_id':'public-synthetic','presentation_grade':'A','selection_status':'auto','kit':{'skeleton':'tactical-board','skin':'neutral-readable','cast':'tactical-team','feedback_modules':['core-feedback']},'view_contract':{'state_source':'shared','player_mode':'player','analysis_mode':'analysis','toggles':['background','motion','vfx','audio']},'presentation_brief':{'decision_owner':'fixture','input_type':'sketch','experience_moment':'synthetic test','first_screen_focus':'current action','core_feedback_moment':'result','resource_exclusions':['unreviewed']},'asset_source':{'repository_id':'prototype-assets'},'assets':[{'asset_id':asset['asset_id'],'export_sha256':asset['files']['export_sha256']}]}
   file=Path(t)/'selection.json';file.write_text(json.dumps(selection),encoding='utf-8')
   args=[shell,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(fromdemotospec/'scripts/import-presentation-assets.ps1'),'-SelectionPath',str(file),'-ProjectPath',str(project)]
   self.command([*args,'-AssetRepositoryPath',str(assets),'-PublicRelease'],fromdemotospec);self.assertFalse((project/'presentation/asset-manifest.json').exists())
   self.command([*args,'-AssetRepositoryPath',str(assets),'-PublicRelease','-Apply'],fromdemotospec)
   shutil.rmtree(assets)
   offline=json.loads(self.command([*args,'-VerifyOffline'],fromdemotospec).stdout);self.assertFalse(offline['network_accessed'])
 def test_both_hosts_discover_new_and_legacy_paths_and_consume_actual_body(self):
  with tempfile.TemporaryDirectory(prefix='aws-bindings-') as t:
   target=Path(t)/'host';w.install(ROOT,target,'init',['meta','brainstorm','fromdemotospec','game-analysis-decision','knowledge','skills','game-presentation','prototype-assets'],True,mode='compatible')
   gameAnalysisDecision=target/'modules/game-analysis-decision';offline=target/'modules/_offline-gameAnalysisDecision';legacy=target/'modules/GameAnalysisDecision'
   for host,script,identity in [('brainstorm','brainstorm-analysis-adapter.mjs','brainstorm'),('fromdemotospec','fromdemotospec-analysis-adapter.mjs','fromdemotospec')]:
    module=target/'modules'/host;request=module/'examples/game-analysis-decision/request-v2.json'
    args=['node','scripts/'+script,'prepare-request','--input',str(request)]
    prepared=json.loads(self.command(args,module).stdout);self.assertEqual(2,prepared['schema_version']);self.assertNotIn('game_analysis_decision_status',prepared)
    report=Path(t)/'analysis.md';body='Synthetic capacity result: 12 required units exceed 10 shared units. Independent pools change the conclusion.\n';report.write_text(body,encoding='utf-8',newline='\n')
    req=json.loads(request.read_text(encoding='utf-8'));common={k:req[k] for k in ['schema_version','request_id','adapter_id','host_ref','host_write_target_ref']}
    intake={**common,'delivery_id':'HOF-public-test','endpoint':'analysis_report','result_ref':'analysis:synthetic','result_status':'complete','action_class':'analysis_only','body':{'path':'analysis.md','sha256':hashlib.sha256(body.encode()).hexdigest(),'format':'markdown'},'source_refs':['project:synthetic'],'limitations':['Synthetic integration, not actual design acceptance']}
    intake_path=Path(t)/'intake.json';intake_path.write_text(json.dumps(intake),encoding='utf-8');delivery=Path(t)/'delivery.json';consumer=Path(t)/'consumer.json';consumer.write_text(json.dumps({'hostType':identity,'hostRef':req['host_ref'],'artifactRoot':t}),encoding='utf-8')
    code="import fs from 'node:fs';import {pathToFileURL} from 'node:url';const api=await import(pathToFileURL(process.argv[1]).href);const d=api.prepareDeliveryV2(JSON.parse(fs.readFileSync(process.argv[2],'utf8')),{artifactRoot:process.argv[3]});fs.writeFileSync(process.argv[4],JSON.stringify(d));"
    self.command(['node','--input-type=module','-e',code,str(gameAnalysisDecision/'scripts/adapter-v2.mjs'),str(intake_path),t,str(delivery)],module)
    consumed=json.loads(self.command(['node','scripts/'+script,'consume-delivery','--input',str(delivery),'--consumer',str(consumer)],module).stdout)
    self.assertEqual(body,consumed['body']);self.assertFalse(consumed['formal_decision_written']);self.assertFalse(consumed['executed'])
    gameAnalysisDecision.rename(offline)
    absent=json.loads(self.command(args,module).stdout);self.assertEqual('unavailable',absent['game_analysis_decision_status']);self.assertFalse(absent['automatic_expert_fallback'])
    offline.rename(legacy);legacy_result=json.loads(self.command(args,module).stdout);self.assertNotIn('game_analysis_decision_status',legacy_result);legacy.rename(gameAnalysisDecision)
    engine=gameAnalysisDecision/'scripts/adapter-v2.mjs';original=engine.read_bytes();engine.write_text("throw Error('present-but-broken dependency');\n")
    broken=self.command(args,module,ok=False);self.assertNotEqual(0,broken.returncode);self.assertIn('present-but-broken',broken.stderr);engine.write_bytes(original)

if __name__=='__main__':unittest.main()
