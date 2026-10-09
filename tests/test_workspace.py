import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import workspace as w
from publish import inventory


def fixture(root, release='1.0.0', previous='legacy'):
    result = {'schema_version': 1, 'version': release, 'previous_version': previous, 'components': {}}
    for name in ('meta', 'brainstorm', 'fromdemotospec', 'knowledge'):
        source = 'meta/workspace' if name == 'meta' else 'packages/' + name
        folder = root / source
        folder.mkdir(parents=True, exist_ok=True)
        if not (folder / 'README.md').exists():
            (folder / 'README.md').write_text(name + ' initial\n', encoding='utf-8', newline='\n')
        result['components'][name] = {'version': release, 'source': source, 'destination': '' if name == 'meta' else 'modules/' + name, 'files': inventory(folder)}
    (root / 'upgrades').mkdir(exist_ok=True)
    (root / 'upgrades' / (release + '.md')).write_text('Upgrade from ' + previous, encoding='utf-8')
    (root / 'catalog.json').write_bytes(w.encoded(result))


class Installation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='agentworkspace-contract-')
        self.base = Path(self.temp.name)
        self.bundle, self.target = self.base / 'bundle', self.base / 'user'
        fixture(self.bundle)

    def tearDown(self):
        self.temp.cleanup()

    def init(self, packages=None):
        return w.install(self.bundle, self.target, 'init', packages or [], True)

    def next(self):
        folder = self.base / 'next'
        shutil.copytree(self.bundle, folder)
        (folder / 'meta/workspace/README.md').write_text('new framework\n', encoding='utf-8')
        fixture(folder, '1.1.0', '1.0.0')
        return folder

    def test_dry_run_creates_nothing_and_repeat_is_idempotent(self):
        report = w.install(self.bundle, self.target, 'init', ['brainstorm'])
        self.assertTrue(report['changes'])
        self.assertFalse(self.target.exists())
        self.init(['brainstorm'])
        self.assertFalse(w.install(self.bundle, self.target, 'init', ['brainstorm'], True)['changes'])

    def test_add_preserves_local_changes_and_business_data(self):
        self.init(['brainstorm'])
        (self.target / 'README.md').write_text('my root configuration', encoding='utf-8')
        personal = self.target / 'modules/brainstorm/workspace/sessions/real.txt'
        personal.parent.mkdir(parents=True)
        personal.write_text('personal data', encoding='utf-8')
        report = w.install(self.bundle, self.target, 'add', ['knowledge'], True)
        self.assertFalse(report['conflicts'])
        self.assertEqual('my root configuration', (self.target / 'README.md').read_text())
        self.assertEqual('personal data', personal.read_text())

    def test_upgrade_changes_only_managed_unmodified_files_and_rollback(self):
        self.init(['brainstorm'])
        personal = self.target / 'my-data.txt'
        personal.write_bytes(b'kept')
        report = w.install(self.next(), self.target, 'upgrade', [], True)
        self.assertTrue(report['applied'])
        self.assertEqual('1.1.0', w.state(self.target)['version'])
        w.rollback(self.target, report['transaction'], True)
        self.assertEqual('1.0.0', w.state(self.target)['version'])
        self.assertEqual(b'kept', personal.read_bytes())

    def test_conflict_prevents_every_write(self):
        self.init()
        (self.target / 'README.md').write_text('my changes', encoding='utf-8')
        before = inventory(self.target)
        report = w.install(self.next(), self.target, 'upgrade', [], True)
        self.assertEqual(['README.md'], report['conflicts'])
        self.assertEqual(before, inventory(self.target))

    def test_upgrade_failure_restores_files_and_registry(self):
        self.init()
        before = (self.target / 'README.md').read_bytes(), (self.target / w.STATE).read_bytes()
        with self.assertRaises(OSError):
            w.install(self.next(), self.target, 'upgrade', [], True, fail_after=1)
        self.assertEqual(before, ((self.target / 'README.md').read_bytes(), (self.target / w.STATE).read_bytes()))

    def test_recovery_preserves_post_upgrade_user_edits(self):
        self.init()
        report = w.install(self.next(), self.target, 'upgrade', [], True)
        (self.target / 'README.md').write_text('edited after upgrade', encoding='utf-8')
        before = inventory(self.target)
        result = w.rollback(self.target, report['transaction'], True)
        self.assertEqual(['README.md'], result['conflicts'])
        self.assertEqual(before, inventory(self.target))

    def test_unknown_schema_version_and_same_version_mutation_rejected(self):
        self.init()
        changed = self.bundle / 'meta/workspace/README.md'
        changed.write_text('silently mutated release', encoding='utf-8')
        fixture(self.bundle)
        with self.assertRaises(w.ContractError):
            w.install(self.bundle, self.target, 'upgrade', [], True)
        incoming = json.loads((self.bundle / 'catalog.json').read_text())
        incoming['schema_version'] = 99
        (self.bundle / 'catalog.json').write_bytes(w.encoded(incoming))
        with self.assertRaises(w.ContractError):
            w.catalog(self.bundle)

    def test_malformed_or_escaping_paths_rejected(self):
        for value in ('../escape', 'a/../../escape', 'C:/x', '/tmp/x', 'x\\y', 'a//b', 'a/./b', 'NUL.txt', 'x:stream', 'a.'):
            with self.subTest(value=value), self.assertRaises(w.ContractError):
                w.safe(self.target, value)

    def test_unmanaged_existing_file_is_not_overwritten(self):
        self.target.mkdir()
        (self.target / 'README.md').write_text('existing project', encoding='utf-8')
        before = inventory(self.target)
        self.assertEqual(['README.md'], self.init()['conflicts'])
        self.assertEqual(before, inventory(self.target))

    def test_unknown_release_jump_and_target_overlap_rejected(self):
        self.init()
        future = self.next()
        fixture(future, '2.0.0', '1.9.0')
        with self.assertRaises(w.ContractError):
            w.install(future, self.target, 'upgrade', [], True)
        with self.assertRaises(w.ContractError):
            w.install(self.bundle, self.bundle / 'user', 'init', [], True)

    def test_link_escape_rejected(self):
        self.target.mkdir()
        outside = self.base / 'outside'
        outside.mkdir()
        try:
            (self.target / 'modules').symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest('Symlink creation unavailable in this environment')
        with self.assertRaises(w.ContractError):
            self.init(['brainstorm'])
        self.assertFalse(list(outside.iterdir()))

    def test_user_deleted_framework_file_not_resurrected_on_add(self):
        self.init()
        (self.target / 'README.md').unlink()
        self.assertFalse(w.install(self.bundle, self.target, 'add', ['fromdemotospec'], True)['conflicts'])
        self.assertFalse((self.target / 'README.md').exists())

    def legacy(self, modified=False):
        self.init()
        folder = self.target / 'modules/brainstorm'
        folder.mkdir(parents=True)
        marker = w.encoded({'source_revision': 'a' * 40})
        baseline = {'README.md': b'legacy framework\n', '_release.json': marker}
        for name, content in baseline.items():
            (folder / name).write_bytes(content)
        (folder / 'my-session.txt').write_bytes(b'original user decision')
        if modified:
            (folder / 'README.md').write_bytes(b'user customized legacy framework')
        summary = {'schema_version': 1, 'component_id': 'brainstorm', 'source_revision': 'a' * 40, 'files': {name: [w.digest(data)] for name, data in baseline.items()}, 'canonical_sha256': {name: w.digest(data) for name, data in baseline.items()}}
        (self.bundle / 'upgrades/legacy').mkdir()
        (self.bundle / 'upgrades/legacy/brainstorm.json').write_bytes(w.encoded(summary))
        return folder

    def test_legacy_adoption_and_upgrade_preserve_user_data(self):
        folder = self.legacy()
        before = inventory(folder)
        w.adopt(self.bundle, self.target, ['brainstorm'], True)
        self.assertEqual(before, inventory(folder))
        report = w.install(self.bundle, self.target, 'upgrade', [], True)
        self.assertTrue(report['applied'])
        self.assertEqual(b'original user decision', (folder / 'my-session.txt').read_bytes())
        self.assertEqual(b'brainstorm initial\n', (folder / 'README.md').read_bytes())

    def test_legacy_user_modification_conflicts_without_overwrite(self):
        folder = self.legacy(modified=True)
        w.adopt(self.bundle, self.target, ['brainstorm'], True)
        before = inventory(self.target)
        report = w.install(self.bundle, self.target, 'upgrade', [], True)
        self.assertEqual(['modules/brainstorm/README.md'], report['conflicts'])
        self.assertEqual(before, inventory(self.target))

    def test_unknown_legacy_identity_is_rejected(self):
        folder = self.legacy()
        (folder / '_release.json').write_bytes(w.encoded({'source_revision': 'b' * 40}))
        before = inventory(self.target)
        with self.assertRaises(w.ContractError):
            w.adopt(self.bundle, self.target, ['brainstorm'], True)
        self.assertEqual(before, inventory(self.target))


if __name__ == '__main__':
    unittest.main(verbosity=2)
