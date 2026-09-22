#!/usr/bin/env python3
"""Back up and replace the two Primer cores on an existing TangCore USB drive."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

from build_tangcore_source import verify_package

CORES = ('monitor.bin', 'nestang.bin')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy_verified(source, destination, expected):
    with source.open('rb') as src, destination.open('xb') as dst:
        shutil.copyfileobj(src, dst)
        dst.flush()
        os.fsync(dst.fileno())
    if digest(destination) != expected:
        raise RuntimeError(f'Copy verification failed: {destination}')


def install(package, media):
    package, media = Path(package).resolve(), Path(media).resolve()
    manifest = verify_package(package)
    core_dir = media / 'cores/primer25k'
    backup_parent = media / 'nestv-backups'
    if not core_dir.resolve().is_relative_to(media) or backup_parent.is_symlink():
        raise RuntimeError('Core and backup directories must stay on the media')
    for name in CORES:
        path = core_dir / name
        if path.is_symlink() or not path.is_file():
            raise RuntimeError(f'Expected existing regular core file: {path}')
    previous = {name: digest(core_dir / name) for name in CORES}
    backup = backup_parent / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    backup.mkdir(parents=True, exist_ok=False)
    # Finish both verified backups before replacing either live core.
    for name in CORES:
        copy_verified(core_dir / name, backup / name, previous[name])
    with (backup / 'manifest.json').open('x') as record:
        json.dump({'previous_sha256': previous, 'replacement_package': manifest}, record, indent=2)
        record.write('\n')
        record.flush()
        os.fsync(record.fileno())
    os.sync()
    print(f'Previous cores backed up to: {backup}', flush=True)
    with tempfile.TemporaryDirectory(prefix='.nestv-install-', dir=core_dir) as staging:
        staging = Path(staging)
        for name in CORES:
            relative = f'media/cores/primer25k/{name}'
            copy_verified(package / relative, staging / name, manifest['sha256'][relative])
        replaced = []
        try:
            for name in CORES:
                os.replace(staging / name, core_dir / name)
                replaced.append(name)
            for name in CORES:
                expected = manifest['sha256'][f'media/cores/primer25k/{name}']
                if digest(core_dir / name) != expected:
                    raise RuntimeError(f'Installed core verification failed: {name}')
        except Exception:
            for name in replaced:
                copy_verified(backup / name, staging / name, previous[name])
                os.replace(staging / name, core_dir / name)
            raise
    # Flush filesystem metadata as well as the file contents before reporting success.
    os.sync()
    print('Installed and verified monitor.bin and nestang.bin. Eject the drive before unplugging.')
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', required=True, type=Path)
    parser.add_argument('--media', required=True)
    args = parser.parse_args()
    if not args.media or not Path(args.media).is_mount():
        parser.error('--media must name the mounted USB drive root')
    install(args.package, Path(args.media))


if __name__ == '__main__':
    main()
