#!/usr/bin/env python3
"""Build matching upstream Primer images in an isolated, pinned source tree."""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
import shutil
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
PINS = {
    'tangcore': ('firmware/tangcore', 'f69c6ff7e21dc43af70465d9428c079f4550abf6'),
    'firmware': ('firmware/tangcore/firmware-bl616', 'a5a6ea1cf7c81f32c1c3f0f91ea9d913be5ba078'),
    'nestang': ('rtl/core/nestang', 'c2450818e1f0c858e13c5dd16746ee5221a5c760'),
    'monitor': ('firmware/tangcore/monitor', 'e4446093a754205f46e7000e6ef1bf37176bda19'),
}
SDK_PIN = '7f44f9ea6b4ccf96db8c5236c8024b68e2a76df7'


def run(*args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def archive(repo, revision, target, *paths):
    data = subprocess.check_output(['git', '-C', str(repo), 'archive', revision, *paths])
    target.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(target, filter='data')


def replace(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f'{path}: expected exactly one {old!r}')
    path.write_text(text.replace(old, new))


def verify_package(package):
    package = Path(package).resolve()
    metadata = json.loads((package / 'manifest.json').read_text())
    expected = {'firmware/tangcore_primer25k.bin',
                'media/cores/primer25k/monitor.bin',
                'media/cores/primer25k/nestang.bin'}
    if (metadata.get('protocol') != 'upstream-framed' or
            metadata.get('complete_fpga_firmware_set') is not True or
            set(metadata.get('sha256', {})) != expected):
        raise RuntimeError('Not a complete matching Primer source package')
    for name, digest in metadata['sha256'].items():
        if hashlib.sha256((package / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f'Package checksum mismatch: {name}')
    return metadata


def package_build(output, firmware_only=False):
    metadata = json.loads((output / 'sources.json').read_text())
    artifacts = {'firmware/tangcore_primer25k.bin': output / 'firmware/build/build_out/tangcore_bl616.bin'}
    if not firmware_only:
        artifacts.update({
            'media/cores/primer25k/monitor.bin': output / 'monitor/impl/pnr/monitor_primer25k.bin',
            'media/cores/primer25k/nestang.bin': output / 'nestang/impl/pnr/nestang_primer25k_ds2.bin',
        })
    package = output / 'package'
    for name, source in artifacts.items():
        dest = package / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
    metadata['sha256'] = {name: hashlib.sha256((package / name).read_bytes()).hexdigest() for name in artifacts}
    metadata['complete_fpga_firmware_set'] = not firmware_only
    (package / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
    if not firmware_only:
        verify_package(package)
    print(f'Built package: {package}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/tangcore-source' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ'))
    parser.add_argument('--sdk', type=Path, default=ROOT / '.tools/bl616/bouffalo_sdk')
    parser.add_argument('--n64-adapter', action='store_true', help='Enable experimental six-byte adapter mapping')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--firmware-only', action='store_true')
    parser.add_argument('--verify-package', type=Path, help='Verify a complete package without building')
    args = parser.parse_args()
    if args.verify_package:
        verify_package(args.verify_package)
        print('Package verified')
        return
    output = args.output.resolve()
    # Refuse to overwrite builds or recovery files. Select a new output for each run.
    output.mkdir(parents=True, exist_ok=False)
    sdk = args.sdk.resolve()
    for name, (repo, revision) in PINS.items():
        if name != 'tangcore':
            archive(ROOT / repo, revision, output / name)
    # Derive a dedicated board from pristine SDK objects, ignoring local SDK edits.
    archive(sdk, SDK_PIN, output / 'sdk-board', 'bsp/board/bl616dk')
    board_root = output / 'sdk-board/bsp/board'
    board = board_root / 'bl616dk'
    replace(board / 'board.c', 'GLB_Power_On_XTAL_And_PLL_CLK(GLB_XTAL_40M, GLB_PLL_WIFIPLL | GLB_PLL_AUPLL);', 'GLB_Power_On_XTAL_And_PLL_CLK(GLB_XTAL_26M, GLB_PLL_WIFIPLL | GLB_PLL_AUPLL);')
    replace(board / 'fw_header.c', '.clk_cfg.cfg.xtal_type = 0x07', '.clk_cfg.cfg.xtal_type = 0x05')
    # The rest of the SDK must match the pin. Allow only the old local board fixes,
    # which BOARD_DIR supersedes, and untracked build/tool output.
    head = subprocess.check_output(['git', '-C', str(sdk), 'rev-parse', 'HEAD'], text=True).strip()
    changed = subprocess.check_output(['git', '-C', str(sdk), 'diff', SDK_PIN, '--name-only'], text=True).splitlines()
    if head != SDK_PIN or any(not p.startswith('bsp/board/bl616dk/') for p in changed):
        raise RuntimeError('SDK must match the pinned revision outside the overridden board directory')
    patch = ROOT / 'firmware/bl616-primer25k-source.patch'
    run('git', 'apply', '--unsafe-paths', '--directory=' + str(output / 'firmware'), patch)
    monitor_patch = ROOT / 'firmware/monitor-primer25k-source.patch'
    run('git', 'apply', '--unsafe-paths', '--directory=' + str(output / 'monitor'), monitor_patch)
    # Match our existing NesTV VCO correction, retaining the same output frequencies.
    for name, filename, divisors in [
        ('nestang', 'gowin_pll_hdmi.v', [(0, 4, 2)]),
        ('monitor', 'pll_74.v', [(0, 20, 10), (1, 4, 2)]),
    ]:
        pll = output / name / 'src/plla' / filename
        replace(pll, 'MDIV_SEL = 55;', 'MDIV_SEL = 27;')
        replace(pll, 'MDIV_FRAC_SEL = 0;', 'MDIV_FRAC_SEL = 4;')
        for index, old, new in divisors:
            replace(pll, f'ODIV{index}_SEL = {old};', f'ODIV{index}_SEL = {new};')
    metadata = {
        'sources': {name: revision for name, (_, revision) in PINS.items()},
        'sdk': SDK_PIN, 'protocol': 'upstream-framed',
        'experimental_n64_adapter': args.n64_adapter,
        'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
        'monitor_patch_sha256': hashlib.sha256(monitor_patch.read_bytes()).hexdigest(),
        'builder_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'gowin_launcher_sha256': hashlib.sha256((ROOT / 'scripts/run_gowin.sh').read_bytes()).hexdigest(),
        'hardware_validated': False,
    }
    (output / 'sources.json').write_text(json.dumps(metadata, indent=2) + '\n')
    if args.prepare_only:
        print(output)
        return
    env = os.environ.copy()
    toolchain = ROOT / '.tools/bl616/toolchain_gcc_t-head_linux/bin'
    if toolchain.is_dir():
        env['PATH'] = str(toolchain) + os.pathsep + env['PATH']
    # Pass the additional option through the project's existing make definitions.
    extra = 'ON' if args.n64_adapter else 'OFF'
    with (output / 'firmware/Makefile').open('a') as makefile:
        makefile.write(f'\ncmake_definition+=-DNESTV_EXPERIMENTAL_N64_ADAPTER={extra}\n')
    run('make', '-C', output / 'firmware', f'BL_SDK_BASE={sdk}',
        f'BOARD_DIR={board_root}', 'BOARD=bl616dk', 'TANG_BOARD=primer25k', env=env)
    if not args.firmware_only:
        for name in ('monitor', 'nestang'):
            run(ROOT / 'scripts/run_gowin.sh', 'build.tcl', 'primer25k', cwd=output / name)
    package_build(output, args.firmware_only)


if __name__ == '__main__':
    main()
