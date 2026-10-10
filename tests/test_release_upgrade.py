import io,json,subprocess,sys,tarfile,tempfile,unittest,shutil,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import workspace as w
from publish import inventory

class ActualReleaseUpgrade(unittest.TestCase):
 def command(self,*args,cwd=None,ok=True):
  r=subprocess.run([str(a) for a in args],cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
  if ok:self.assertEqual(0,r.returncode,r.stdout[-2000:]+r.stderr[-2000:])
  return r
 def test_real_120_upgrade_add_and_rollback_preserve_local_data(self):
  with tempfile.TemporaryDirectory(prefix='aws-real-upgrade-') as t:
   base=Path(t);old=base/'old';old.mkdir();target=base/'host'
   git=shutil.which('git');self.assertIsNotNone(git)
   def snapshot(ref,destination):
    destination.mkdir(exist_ok=True)
    r=subprocess.run([git,'-c','safe.directory='+ROOT.as_posix(),'-C',str(ROOT),'archive',ref],capture_output=True)
    self.assertEqual(0,r.returncode,r.stderr.decode(errors='replace'))
    with tarfile.open(fileobj=io.BytesIO(r.stdout)) as archive:
     for member in archive:
      if member.isdir():continue
      self.assertTrue(member.isfile());p=w.safe(destination,member.name);p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(archive.extractfile(member).read())
   snapshot('v1.2.0',old);intermediate=base/'intermediate';snapshot('v1.3.0',intermediate)
   self.command(sys.executable,'-X','utf8','-B',old/'scripts/workspace.py','init','--target',target,'--packages','brainstorm','fromdemotospec','knowledge','--apply')
   user=target/'modules/brainstorm/sessions/my-note.md';user.parent.mkdir(parents=True,exist_ok=True);user.write_bytes(b'User data must remain.\n')
   rules=target/'AGENTS.md';rules.write_bytes(rules.read_bytes()+b'\nLocal host addition.\n');original=rules.read_bytes()
   first=self.command(sys.executable,'-X','utf8','-B',intermediate/'scripts/workspace.py','upgrade','--target',target,'--apply');first_transaction=json.loads(first.stdout)['transaction']
   self.assertEqual('1.3.0',w.state(target)['version'])
   preview=w.install(ROOT,target,'upgrade',[]);self.assertFalse(preview['applied']);self.assertFalse(preview['conflicts'])
   upgraded=w.install(ROOT,target,'upgrade',[],True);self.assertEqual('1.3.1',w.state(target)['version']);self.assertEqual(original,rules.read_bytes());self.assertEqual({'meta','brainstorm','fromdemotospec','knowledge'},set(w.state(target)['components']))
   added=w.install(ROOT,target,'add',['skills','game-analysis-decision','game-presentation','prototype-assets'],True)
   self.assertTrue(added['applied']);self.assertEqual(8,len(w.state(target)['components']));self.assertFalse((target/'.agents/skills/property-based-testing').exists())
   self.assertTrue(w.rollback(target,added['transaction'],True)['applied']);self.assertFalse((target/'modules/skills/README.md').exists())
   self.assertTrue(w.rollback(target,upgraded['transaction'],True)['applied']);self.assertEqual('1.3.0',w.state(target)['version']);self.assertTrue(w.rollback(target,first_transaction,True)['applied']);self.assertEqual('1.2.0',w.state(target)['version']);self.assertEqual(original,rules.read_bytes());self.assertEqual(b'User data must remain.\n',user.read_bytes())
 def test_skill_upgrade_only_selected_and_local_changes(self):
  with tempfile.TemporaryDirectory(prefix='aws-skill-upgrade-') as t:
   base=Path(t);old=ROOT/'packages/skills';new=base/'next';shutil.copytree(old,new);target=base/'host'
   def pick(bundle,*args,ok=True):
    r=self.command(sys.executable,'-X','utf8','-B',bundle/'scripts/skills.py',*args,'--target',target,ok=ok)
    return r,json.loads(r.stdout) if r.stdout else None
   pick(old,'install','--names','systematic-debugging','property-based-testing','--apply')
   debug=target/'.agents/skills/systematic-debugging/SKILL.md';original=debug.read_bytes();debug.write_bytes(original+b'\nUser edit\n')
   upstream=new/'library/systematic-debugging/SKILL.md';upstream.write_bytes(upstream.read_bytes()+b'\nSynthetic next-version test annotation.\n')
   cat=json.loads((new/'catalog.json').read_text());cat.update(version='1.4.0',previous_version='1.3.0')
   for item in cat['components'].values():item.update(version='1.4.0',files=inventory(new/item['source']))
   (new/'catalog.json').write_bytes(w.encoded(cat));(new/'upgrades/1.4.0.md').write_text('Synthetic upgrade fixture only.\n')
   denied,report=pick(new,'upgrade','--apply',ok=False);self.assertNotEqual(0,denied.returncode);self.assertTrue(report['conflicts']);self.assertEqual(original+b'\nUser edit\n',debug.read_bytes())
   debug.write_bytes(original)
   property_file=target/'.agents/skills/property-based-testing/SKILL.md';local=property_file.read_bytes()+b'\nLocal unrelated annotation.\n';property_file.write_bytes(local)
   _,report=pick(new,'upgrade','--apply');self.assertTrue(report['applied']);self.assertEqual(2,len(json.loads((target/'.agent-skills/codex/state.json').read_text())['components']));self.assertEqual(local,property_file.read_bytes());self.assertEqual(upstream.read_bytes(),debug.read_bytes())
   pick(new,'rollback','--transaction',report['transaction'],'--apply');self.assertEqual(original,debug.read_bytes());self.assertEqual(local,property_file.read_bytes())

if __name__=='__main__':unittest.main()
