import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import publish as p


class PublicationRecovery(unittest.TestCase):
    def test_failed_renames_preserve_previous_package(self):
        for fail_old in (True, False):
            with self.subTest(fail_original_rename=fail_old), tempfile.TemporaryDirectory(prefix='publication-recovery-') as temporary:
                root = Path(temporary)
                (root / 'scripts').mkdir()
                (root / 'scripts/workspace.py').write_text('# fixture')
                (root / 'AGENTS.md').write_text('# fixture')
                target = root / 'packages/brainstorm'
                target.mkdir(parents=True)
                (target / 'README.md').write_bytes(b'previous release')
                original = p.inventory(target)
                def stage(source, destination):
                    (destination / 'README.md').write_bytes(b'next release')
                    return {'component_id': 'brainstorm', 'output_path': 'packages/brainstorm'}, False
                rename = Path.rename
                def broken(path, dest):
                    if fail_old and path == target or not fail_old and path.name.startswith('.publish-') and Path(dest) == target and (path / 'README.md').read_bytes() == b'next release':
                        raise OSError('Injected directory replacement failure')
                    return rename(path, dest)
                with patch.object(p, 'stage', stage), patch.object(Path, 'rename', broken):
                    with self.assertRaises(OSError):
                        p.export(root, root, True)
                self.assertEqual(original, p.inventory(target))


if __name__ == '__main__':
    unittest.main(verbosity=2)
