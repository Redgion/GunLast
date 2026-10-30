import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('gunlast', Path(__file__).parents[1] / 'gunlast.py')
g = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(g)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='GunLast тест ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.game = self.root / 'Steam Library/Outlast'
        self.payload = self.root / 'Files'
        for rel in ('Binaries/Win64/OLGame.exe', 'OLGame/Config/DefaultEngine.ini',
                    'OLGame/Config/DefaultGame.ini', 'OLGame/Config/DefaultInput.ini',
                    'OLGame/Config/OLGame.ini', 'OLGame/Config/OLInput.ini'):
            self.write(self.game / rel, b'original')
        (self.game / 'OLGame/CookedPCConsole').mkdir()
        self.files = {}
        for rel in g.manifest():
            self.write(self.payload / rel, ('payload ' + rel).encode())
            self.files[rel] = g.digest(self.payload / rel)
        self.original = self.snapshot()
        self.patcher = patch.object(g, 'manifest', return_value=self.files)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def snapshot(self):
        return {p.relative_to(self.game).as_posix(): p.read_bytes()
                for p in self.game.rglob('*') if p.is_file() and '.gunlast' not in p.parts}

    def install(self):
        with contextlib.redirect_stdout(io.StringIO()):
            g.install(self.game, self.payload)

    def test_roundtrip_and_reinstall_with_legacy(self):
        for rel in g.LEGACY:
            self.write(self.game / rel, b'legacy')
        original = self.snapshot()
        self.install()
        for rel in g.LEGACY:
            self.assertFalse((self.game / rel).exists())
        g.uninstall(self.game)
        self.assertEqual(original, self.snapshot())
        self.install()
        g.uninstall(self.game)

    def test_corrupt_payload_no_mutation(self):
        (self.payload / next(iter(self.files))).write_bytes(b'corrupted')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.install()
        self.assertEqual(self.original, self.snapshot())
        self.assertFalse((self.game / '.gunlast').exists())

    def test_missing_binary_no_mutation(self):
        (self.game / 'Binaries/Win64/OLGame.exe').unlink()
        with self.assertRaisesRegex(ValueError, 'Windows Outlast'):
            self.install()
        self.assertFalse((self.game / '.gunlast').exists())

    def test_symlink_and_traversal(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (self.game / 'Custom').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.install()
        for rel in ('../escape', '/absolute', 'folder/../../escape', 'C:\\escape'):
            with self.assertRaises(ValueError):
                g.safe(self.game, rel)
        self.assertEqual([], list(outside.iterdir()))

    def test_existing_campaign_refused(self):
        (self.game / 'OLGame/CookedPCConsole/Custom/Campaign').mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, 'Campaign already'):
            self.install()

    def test_changed_file_blocks_uninstall(self):
        self.install()
        target = self.game / next(iter(self.files))
        target.write_bytes(b'user edit')
        with self.assertRaisesRegex(ValueError, 'changed'):
            g.uninstall(self.game)
        self.assertEqual(b'user edit', target.read_bytes())

    def test_copy_failure_rolls_back(self):
        copy = g.shutil.copy2
        def fail(source, dest, *args, **kwargs):
            if str(source).startswith(str(self.payload)) and str(source).endswith('DefaultGame.ini'):
                raise OSError('simulated disk error')
            return copy(source, dest, *args, **kwargs)
        with patch.object(g.shutil, 'copy2', side_effect=fail):
            with self.assertRaisesRegex(OSError, 'simulated'):
                self.install()
        self.assertEqual(self.original, self.snapshot())
        self.assertFalse((self.game / '.gunlast').exists())

    def test_launch_and_restore_on_nonzero_exit(self):
        self.install()
        fake = self.root / 'fake proton'
        fake.write_text('#!/usr/bin/env python3\nfrom pathlib import Path\n'
                        'import sys\n'
                        "c=Path('OLGame/Config')\n"
                        "assert (c/'DefaultGame.ini').read_bytes().startswith(b'payload ')\n"
                        "assert not (c/'OLGame.ini').exists()\n"
                        "(c/'OLGame.ini').write_text('generated')\n"
                        "(c/'new.ini').write_text('generated')\n"
                        "assert sys.argv[-3:] == ['-NoSteam','-NOHOMEDIR','-log']\n"
                        'sys.exit(7)\n')
        fake.chmod(0o755)
        result = g.run(self.game, [str(fake), 'waitforexitandrun', str(self.game / 'OutlastLauncher.exe')])
        self.assertEqual(7, result)
        self.assertEqual(b'original', (self.game / 'OLGame/Config/OLGame.ini').read_bytes())
        self.assertFalse((self.game / 'OLGame/Config/new.ini').exists())
        self.assertFalse((self.game / '.gunlast/session.json').exists())
        g.uninstall(self.game)
        self.assertEqual(self.original, self.snapshot())

    def test_interrupted_session_recovery(self):
        self.install()
        base = self.game / '.gunlast'
        config = self.game / 'OLGame/Config'
        g.shutil.copytree(config, base / 'session-backup')
        g.save(base / 'session.json', {'files': g.tree_files(config)})
        (config / 'DefaultGame.ini').write_bytes(b'active mod')
        (config / 'OLNew.ini').write_bytes(b'new')
        g.recover_session(self.game)
        g.recover_session(self.game)
        self.assertEqual(b'original', (config / 'DefaultGame.ini').read_bytes())
        self.assertFalse((config / 'OLNew.ini').exists())

    def test_steam_discovery_secondary_library(self):
        home = self.root / 'home'
        steam = home / '.local/share/Steam/steamapps'
        self.write(steam / 'libraryfolders.vdf', ('"libraryfolders" { "1" { "path" "' +
                   str(self.root / 'Steam Library') + '" } }').encode())
        lib = self.root / 'Steam Library/steamapps'
        self.write(lib / 'appmanifest_238320.acf', b'"AppState" { "installdir" "Outlast" }')
        (lib / 'common/Outlast').mkdir(parents=True)
        with patch.object(g.Path, 'home', return_value=home):
            self.assertEqual([lib / 'common/Outlast'], g.discover())

    def test_native_or_unwrapped_command_rejected(self):
        for command in ([], ['/usr/bin/wine', 'OLGame.exe'], ['/bin/true']):
            with self.assertRaises(ValueError):
                g.launch_command(self.game, command)

    def test_lock(self):
        with g.lock(self.game):
            with self.assertRaisesRegex(ValueError, 'Another GunLast'):
                with g.lock(self.game):
                    pass

    def test_empty_existing_directories_survive_uninstall(self):
        self.install()
        g.uninstall(self.game)
        self.assertTrue((self.game / 'OLGame/CookedPCConsole').is_dir())
        self.install()

    def test_interrupted_install_recovery(self):
        self.install()
        base = self.game / '.gunlast'
        state = json.loads((base / 'state.json').read_text())
        state['phase'] = 'installing'
        g.save(base / 'state.json', state)
        (self.game / next(iter(self.files))).write_bytes(b'partial copy')
        g.uninstall(self.game, recover=True)
        self.assertEqual(self.original, self.snapshot())

    def test_real_manifest_matches_original(self):
        original = json.loads((Path(g.__file__).parents[1] / 'DistributionScripts/manifest.json').read_text())
        shipped = json.loads(Path(g.__file__).with_name('manifest.json').read_text())
        self.assertEqual(shipped['Files'], [e for e in original['Files'] if e['Path'].startswith('Custom/')])


if __name__ == '__main__':
    unittest.main()
