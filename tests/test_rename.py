import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_workspace import fixture
import workspace as w
from publish import inventory


class PackageRename(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rename-contract-')
        self.base = Path(self.temp.name)
        self.old, self.new, self.target = [self.base / name for name in ('old', 'new', 'user')]
        fixture(self.old, '1.0.0', 'legacy')
        catalog = json.loads((self.old / 'catalog.json').read_text(encoding='utf-8'))
        item = catalog['components'].pop('fromdemotospec')
        (self.old / item['source']).rename(self.old / 'packages/f2s')
        item.update(source='packages/f2s', destination='modules/f2s')
        catalog['components']['f2s'] = item
        (self.old / 'catalog.json').write_bytes(w.encoded(catalog))
        fixture(self.new, '1.1.0', '1.0.0')
        (self.new / 'packages/fromdemotospec/README.md').write_bytes(b'updated framework\n')
        catalog = json.loads((self.new / 'catalog.json').read_text(encoding='utf-8'))
        catalog['components']['fromdemotospec']['files'] = inventory(self.new / 'packages/fromdemotospec')
        (self.new / 'catalog.json').write_bytes(w.encoded(catalog))
        w.install(self.old, self.target, 'init', ['f2s'], True)
        (self.target / 'modules/f2s/user-project.txt').write_bytes(b'user original')

    def tearDown(self):
        self.temp.cleanup()

    def test_preview_alias_migration_and_full_rollback(self):
        before = inventory(self.target)
        preview = w.install(self.new, self.target, 'upgrade', [], False)
        self.assertEqual(before, inventory(self.target))
        self.assertEqual('modules/fromdemotospec', preview['moves'][0]['destination'])
        report = w.install(self.new, self.target, 'upgrade', [], True)
        self.assertFalse((self.target / 'modules/f2s').exists())
        self.assertEqual(b'user original', (self.target / 'modules/fromdemotospec/user-project.txt').read_bytes())
        self.assertNotIn('f2s', w.state(self.target)['components'])
        self.assertFalse(w.install(self.new, self.target, 'add', ['f2s'], True)['changes'])
        self.assertTrue(w.rollback(self.target, report['transaction'], True)['applied'])
        self.assertEqual(b'user original', (self.target / 'modules/f2s/user-project.txt').read_bytes())
        self.assertEqual('1.0.0', w.state(self.target)['version'])

    def test_conflicting_framework_or_destination_prevents_every_write(self):
        for destination_conflict in (False, True):
            with self.subTest(destination_conflict=destination_conflict):
                if destination_conflict:
                    (self.target / 'modules/fromdemotospec').mkdir()
                else:
                    (self.target / 'modules/f2s/README.md').write_bytes(b'local framework edits')
                before = inventory(self.target)
                if destination_conflict:
                    with self.assertRaises(w.ContractError):
                        w.install(self.new, self.target, 'upgrade', [], True)
                else:
                    self.assertTrue(w.install(self.new, self.target, 'upgrade', [], True)['conflicts'])
                self.assertEqual(before, inventory(self.target))

    def test_failure_restores_old_directory_files_and_state(self):
        old_state = (self.target / w.STATE).read_bytes()
        old_files = inventory(self.target / 'modules/f2s')
        with self.assertRaises(OSError):
            w.install(self.new, self.target, 'upgrade', [], True, fail_after=1)
        self.assertEqual(old_state, (self.target / w.STATE).read_bytes())
        self.assertEqual(old_files, inventory(self.target / 'modules/f2s'))
        self.assertFalse((self.target / 'modules/fromdemotospec').exists())

    def test_rollback_preserves_later_user_changes(self):
        report = w.install(self.new, self.target, 'upgrade', [], True)
        (self.target / 'modules/fromdemotospec/user-project.txt').write_bytes(b'new user work')
        before = inventory(self.target)
        self.assertTrue(w.rollback(self.target, report['transaction'], True)['conflicts'])
        self.assertEqual(before, inventory(self.target))


if __name__ == '__main__':
    unittest.main(verbosity=2)
