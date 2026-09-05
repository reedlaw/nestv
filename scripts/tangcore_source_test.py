#!/usr/bin/env python3
"""Exercise package integrity checks used before a source firmware flash."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from build_tangcore_source import verify_package


class PackageIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.manifest = {'protocol': 'upstream-framed', 'complete_fpga_firmware_set': True, 'sha256': {}}
        for name in ('firmware/tangcore_primer25k.bin', 'media/cores/primer25k/monitor.bin',
                     'media/cores/primer25k/nestang.bin'):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
            self.manifest['sha256'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.save()

    def save(self):
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_complete_package(self):
        self.assertEqual(verify_package(self.root), self.manifest)

    def test_reject_replaced_core(self):
        (self.root / 'media/cores/primer25k/nestang.bin').write_bytes(b'old release core')
        with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
            verify_package(self.root)

    def test_reject_missing_monitor(self):
        (self.root / 'media/cores/primer25k/monitor.bin').unlink()
        with self.assertRaises(FileNotFoundError):
            verify_package(self.root)

    def test_reject_incomplete_build(self):
        self.manifest['complete_fpga_firmware_set'] = False
        self.save()
        with self.assertRaisesRegex(RuntimeError, 'Not a complete'):
            verify_package(self.root)

    def test_reject_unexpected_paths(self):
        self.manifest['sha256']['../outside.bin'] = '0' * 64
        self.save()
        with self.assertRaisesRegex(RuntimeError, 'Not a complete'):
            verify_package(self.root)

    def test_reject_legacy_protocol(self):
        self.manifest['protocol'] = 'legacy'
        self.save()
        with self.assertRaisesRegex(RuntimeError, 'Not a complete'):
            verify_package(self.root)


if __name__ == '__main__':
    unittest.main()
