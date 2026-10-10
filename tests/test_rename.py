from pathlib import Path
import tempfile
import unittest
from test_workspace import fixture
import workspace as w
from publish import inventory


class PackageNames(unittest.TestCase):
    def test_unknown_abbreviated_package_names_reject_without_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            bundle, target = base / 'bundle', base / 'host'
            fixture(bundle)
            target.mkdir()
            (target / 'my-data.txt').write_bytes(b'Keep my data')
            before = inventory(target)
            for name in ('f2s', 'gad'):
                with self.subTest(name=name), self.assertRaises(w.ContractError):
                    w.install(bundle, target, 'init', [name], True)
                self.assertEqual(before, inventory(target))


if __name__ == '__main__':
    unittest.main()
