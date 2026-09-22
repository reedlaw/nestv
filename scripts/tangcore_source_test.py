#!/usr/bin/env python3
"""Exercise package integrity checks used before a source firmware flash."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import os

from install_tangcore_media import install

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

    def media(self):
        media = self.root / 'drive'
        cores = media / 'cores/primer25k'
        cores.mkdir(parents=True)
        for name in ('monitor.bin', 'nestang.bin'):
            (cores / name).write_bytes(b'previous-' + name.encode())
        (media / 'game.nes').write_bytes(b'keep ROM')
        return media

    def test_media_install_preserves_backup_and_rom(self):
        media = self.media()
        with patch('install_tangcore_media.os.sync'):
            backup = install(self.root, media)
        for name in ('monitor.bin', 'nestang.bin'):
            self.assertEqual((backup / name).read_bytes(), b'previous-' + name.encode())
            self.assertEqual((media / 'cores/primer25k' / name).read_bytes(),
                             (self.root / 'media/cores/primer25k' / name).read_bytes())
        self.assertEqual((media / 'game.nes').read_bytes(), b'keep ROM')

    def test_invalid_package_does_not_touch_media(self):
        media = self.media()
        (self.root / 'media/cores/primer25k/nestang.bin').write_bytes(b'corrupt')
        with self.assertRaises(RuntimeError):
            install(self.root, media)
        self.assertFalse((media / 'nestv-backups').exists())
        self.assertEqual((media / 'cores/primer25k/monitor.bin').read_bytes(), b'previous-monitor.bin')

    def test_second_replacement_failure_restores_first(self):
        media = self.media()
        real_replace = os.replace
        calls = 0

        def fail_second(source, destination):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError('simulated write failure')
            real_replace(source, destination)

        with patch('install_tangcore_media.os.sync'), patch('install_tangcore_media.os.replace', side_effect=fail_second):
            with self.assertRaisesRegex(OSError, 'simulated write failure'):
                install(self.root, media)
        for name in ('monitor.bin', 'nestang.bin'):
            self.assertEqual((media / 'cores/primer25k' / name).read_bytes(), b'previous-' + name.encode())


if __name__ == '__main__':
    unittest.main()
