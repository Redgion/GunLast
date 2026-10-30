#!/usr/bin/env python3
"""GunLast r4 Linux/Steam-Proton installer. Python standard library only."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import signal
import subprocess
import sys

APPID = '238320'
MOD = 'Custom/OutlastPistolMod/'
LEGACY = ('OLGame/CookedPCConsole/OutlastPistolMod.u',
          'OLGame/CookedPCConsole/OutlastPistolMod.OLScript',
          MOD + 'Content/OutlastPistolMod.u')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def safe(root, relative):
    parts = PurePosixPath(relative).parts
    if not parts or relative.startswith('/') or any(p in ('.', '..') for p in parts) or '\\' in relative:
        raise ValueError('Unsafe relative path: ' + relative)
    path = root
    for part in parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Symlink is not supported here: ' + str(path))
    return path


def save(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, indent=2) + '\n')
    tmp.replace(path)


def discover():
    home = Path.home()
    roots = [home / '.local/share/Steam', home / '.steam/steam', home / '.steam/root',
             home / '.var/app/com.valvesoftware.Steam/data/Steam']
    for root in list(roots):
        vdf = root / 'steamapps/libraryfolders.vdf'
        if vdf.is_file():
            roots.extend(Path(p.replace('\\\\', '\\')) for p in
                         re.findall(r'"path"\s*"([^"\n]+)"', vdf.read_text()))
    games = set()
    for root in roots:
        acf = root / ('steamapps/appmanifest_' + APPID + '.acf')
        if acf.is_file():
            match = re.search(r'"installdir"\s*"([^"\n]+)"', acf.read_text())
            if match and '/' not in match[1] and match[1] not in ('.', '..'):
                game = root / 'steamapps/common' / match[1]
                if game.is_dir():
                    games.add(game.resolve())
    return sorted(games)


def game_path(arg):
    if arg:
        return Path(arg).expanduser().resolve(strict=True)
    candidates = discover()
    if len(candidates) != 1:
        raise ValueError('Specify --game PATH; detected: ' + ', '.join(map(str, candidates)))
    return candidates[0]


def check_game(game):
    for rel in ('Binaries/Win64/OLGame.exe', 'OLGame/Config/DefaultEngine.ini',
                'OLGame/Config/DefaultGame.ini', 'OLGame/Config/DefaultInput.ini'):
        if not safe(game, rel).is_file():
            raise ValueError('Windows Outlast required; missing ' + rel +
                             '. In Steam > Properties > Compatibility, force Proton, then update the game.')
    if not safe(game, 'OLGame/CookedPCConsole').is_dir():
        raise ValueError('Missing OLGame/CookedPCConsole')


def closed():
    # Also catches a game launched outside this wrapper. Do not inspect command lines/secrets.
    for entry in Path('/proc').iterdir():
        if entry.name.isdigit():
            try:
                name = (entry / 'comm').read_text().strip().lower()
            except (OSError, UnicodeError):
                continue
            if name.startswith('olgame') or name.startswith('outlastlauncher'):
                raise ValueError('Close Outlast and its launcher first.')


@contextlib.contextmanager
def lock(game):
    path = safe(game, '.gunlast.lock')
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another GunLast operation or game session is running.') from None
        yield


def manifest():
    data = json.loads(Path(__file__).with_name('manifest.json').read_text())
    return {entry['Path']: entry['Sha256'] for entry in data['Files']}


def verified_payload(payload):
    files = manifest()
    for rel, expected in files.items():
        source = safe(payload, rel)
        if not source.is_file() or digest(source) != expected:
            raise ValueError('Missing or checksum mismatch: ' + str(source) +
                             '. Supply the original r4 Files directory; source-only checkout is insufficient.')
    return files


def restore_install(game, state):
    # Idempotent: backups remain available until the complete restore succeeds.
    for item in state['files']:
        if item['before']:
            backup = safe(game / '.gunlast/backup', item['path'])
            if not backup.is_file() or digest(backup) != item['before']:
                raise ValueError('Backup damaged; refusing restore: ' + str(backup))
    for item in reversed(state['files']):
        target = safe(game, item['path'])
        if item['before']:
            backup = safe(game / '.gunlast/backup', item['path'])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup, target)
        elif target.exists():
            target.unlink()
    for rel in sorted(state['created_dirs'], key=lambda value: value.count('/'), reverse=True):
        try:
            safe(game, rel).rmdir()
        except OSError:
            pass



def install(game, payload):
    check_game(game)
    closed()
    files = verified_payload(payload)
    state_dir = safe(game, '.gunlast')
    if state_dir.exists():
        raise ValueError('Already installed or interrupted installation. Use recover/uninstall first.')
    campaign = safe(game, 'OLGame/CookedPCConsole/Custom/Campaign')
    if campaign.exists():
        raise ValueError('Campaign already exists. Unmount other campaigns first.')
    targets = dict(files)
    for rel, sha in files.items():
        if rel.startswith(MOD + 'Content/'):
            targets['OLGame/CookedPCConsole/Custom/Campaign/' + Path(rel).name] = sha
    records = []
    for rel in [*targets, *LEGACY]:
        target = safe(game, rel)
        if target.exists() and not target.is_file():
            raise ValueError('Conflicting non-file: ' + str(target))
        records.append({'path': rel, 'before': digest(target) if target.exists() else None,
                        'after': targets.get(rel)})
    state_dir.mkdir()
    created_dirs = set()
    for rel in targets:
        parent = safe(game, rel).parent
        while parent != game and not parent.exists():
            created_dirs.add(parent.relative_to(game).as_posix())
            parent = parent.parent
    state = {'phase': 'preparing', 'files': records, 'created_dirs': sorted(created_dirs)}
    save(state_dir / 'state.json', state)
    # Never write game files until ALL original bytes have been backed up.
    for item in records:
        if item['before']:
            source = safe(game, item['path'])
            backup = safe(state_dir / 'backup', item['path'])
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, backup)
    shutil.copy2(Path(__file__), state_dir / 'gunlast.py')
    shutil.copy2(Path(__file__).with_name('manifest.json'), state_dir / 'manifest.json')
    state['phase'] = 'installing'
    save(state_dir / 'state.json', state)
    try:
        for item in records:
            target = safe(game, item['path'])
            if item['after']:
                source_rel = item['path']
                if source_rel.startswith('OLGame/CookedPCConsole/Custom/Campaign/'):
                    source_rel = MOD + 'Content/' + target.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(safe(payload, source_rel), target)
                if digest(target) != item['after']:
                    raise ValueError('Installed checksum mismatch: ' + str(target))
            elif target.exists():
                target.unlink()
        state['phase'] = 'installed'
        save(state_dir / 'state.json', state)
    except BaseException:
        restore_install(game, state)
        shutil.rmtree(state_dir)
        raise
    print('Installed. Steam launch options:\n' +
          shlex.join(['python3', str(state_dir / 'gunlast.py'), 'run', '--game', str(game), '--']) +
          ' %command%')


def tree_files(root):
    result = []
    for path in root.rglob('*'):
        if path.is_symlink():
            raise ValueError('Symlink in configuration: ' + str(path))
        if path.is_file():
            result.append(path.relative_to(root).as_posix())
    return result


def recover_session(game):
    base = safe(game, '.gunlast')
    journal = safe(base, 'session.json')
    if not journal.exists():
        return
    session = json.loads(journal.read_text())
    config = safe(game, 'OLGame/Config')
    current = tree_files(config)
    for rel in session['files']:
        target = safe(config, rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(safe(base / 'session-backup', rel), target)
    for rel in current:
        if rel not in session['files']:
            safe(config, rel).unlink()
    journal.unlink()
    shutil.rmtree(base / 'session-backup')


def launch_command(game, command):
    if not command:
        raise ValueError('Run via Steam launch options with -- %command%; do not call system Wine.')
    command = list(command)
    matches = [i for i, arg in enumerate(command)
               if arg.replace('\\', '/').rsplit('/', 1)[-1].lower()
               in ('outlastlauncher.exe', 'olgame.exe')]
    if len(matches) != 1 or not any('proton' in arg.lower() for arg in command[:matches[0]]):
        raise ValueError('Expected Steam Proton command with exactly one Outlast Windows EXE.')
    command[matches[0]] = str(game / 'Binaries/Win64/OLGame.exe')
    return command + ['-NoSteam', '-NOHOMEDIR', '-log']


def run(game, command):
    check_game(game)
    closed()
    cmd = launch_command(game, command)
    base = safe(game, '.gunlast')
    state = json.loads(safe(base, 'state.json').read_text())
    if state['phase'] != 'installed':
        raise ValueError('Incomplete installation; use recover.')
    if safe(base, 'session.json').exists():
        raise ValueError('Interrupted session detected. Close Outlast, then use recover.')
    for item in state['files']:
        target = safe(game, item['path'])
        if item['after'] and (not target.is_file() or digest(target) != item['after']):
            raise ValueError('Installed file changed: ' + str(target))
    config = safe(game, 'OLGame/Config')
    entries = tree_files(config)
    backup = safe(base, 'session-backup')
    if backup.exists():
        shutil.rmtree(backup)  # orphan from interruption before session journal was committed
    shutil.copytree(config, backup)
    save(base / 'session.json', {'files': entries})
    try:
        # UE3 generated configs can otherwise override DefaultGame and input bindings.
        for rel in entries:
            path = safe(config, rel)
            if path.name.lower().startswith('ol') and path.suffix.lower() == '.ini':
                path.unlink()
        for name in ('DefaultEngine.ini', 'DefaultGame.ini', 'DefaultInput.ini'):
            shutil.copy2(safe(game, MOD + 'Config/' + name), config / name)
        child = subprocess.Popen(cmd, cwd=game, start_new_session=True)
        previous = {}
        def forward(signum, frame):
            if child.poll() is None:
                os.killpg(child.pid, signum)
        try:
            for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
                previous[sig] = signal.signal(sig, forward)
            return child.wait()
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
    finally:
        # If a Proton wrapper exited while the game survives, leave journal for recovery.
        closed()
        recover_session(game)


def uninstall(game, recover=False):
    closed()
    base = safe(game, '.gunlast')
    state = json.loads(safe(base, 'state.json').read_text())
    recover_session(game)
    if state['phase'] != 'preparing':
        if not recover:
            for item in state['files']:
                path = safe(game, item['path'])
                actual = digest(path) if path.is_file() else None
                if actual != item['after']:
                    raise ValueError('File changed since installation; refusing overwrite: ' + str(path))
        restore_install(game, state)
    shutil.rmtree(base)
    print('Original installation files restored. Clear Steam launch options.')


def doctor(game, payload=None):
    print('Game:', game)
    print('Win64:', (game / 'Binaries/Win64/OLGame.exe').is_file())
    print('Native Linux:', (game / 'Binaries/Linux/OLGame.x86_64').is_file())
    print('Proton prefix (Steam library):', game.parent.parent / ('compatdata/' + APPID + '/pfx'))
    check_game(game)
    if payload:
        verified_payload(payload)
        print('All seven r4 payload checksums verified.')
    print('Preflight passed; this is not an in-game compatibility test.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['doctor', 'install', 'run', 'recover', 'uninstall'])
    parser.add_argument('--game', help='Outlast game root (otherwise detect Steam libraries)')
    parser.add_argument('--payload', type=Path, help='Extracted original r4 Files directory')
    argsv = sys.argv[1:]
    command = []
    if '--' in argsv:
        index = argsv.index('--')
        command, argsv = argsv[index + 1:], argsv[:index]
    args = parser.parse_args(argsv)
    try:
        game = game_path(args.game)
        if args.action == 'doctor':
            doctor(game, args.payload)
            return 0
        with lock(game):
            if args.action == 'install':
                if not args.payload:
                    raise ValueError('--payload /path/to/Files is required.')
                install(game, args.payload.resolve(strict=True))
            elif args.action == 'run':
                return run(game, command)
            elif args.action == 'uninstall':
                uninstall(game)
            else:
                closed()
                state = json.loads(safe(game, '.gunlast/state.json').read_text())
                if state['phase'] == 'installed':
                    recover_session(game)
                    print('Session configuration recovered; mod remains installed.')
                else:
                    uninstall(game, recover=True)
        return 0
    except (OSError, ValueError, KeyError) as exc:
        print('GunLast: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
