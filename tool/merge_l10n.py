#!/usr/bin/env python3
"""Merges ARB fragments from lib/l10n/fragments into lib/l10n/arb and runs gen-l10n.

Fragments are named `<group>_<locale>.arb` (e.g. `scanner_en.arb`, `scanner_uk.arb`).
Only `en` (template) and `uk` are built from fragments; other locales are
maintained directly in lib/l10n/arb/app_<locale>.arb.

Usage: python3 tool/merge_l10n.py [--no-gen]
"""
import fcntl
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAG_DIR = os.path.join(ROOT, 'lib', 'l10n', 'fragments')
ARB_DIR = os.path.join(ROOT, 'lib', 'l10n', 'arb')
FRAGMENT_LOCALES = ('en', 'uk')


def main() -> int:
    os.makedirs(ARB_DIR, exist_ok=True)
    lock_path = os.path.join(ROOT, 'build', '.l10n_merge.lock')
    os.makedirs(os.path.dirname(lock_path), exist_ok=True)
    with open(lock_path, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        errors = []
        for locale in FRAGMENT_LOCALES:
            merged = {'@@locale': locale}
            owners = {}
            for path in sorted(glob.glob(os.path.join(FRAG_DIR, f'*_{locale}.arb'))):
                name = os.path.basename(path)
                try:
                    with open(path, encoding='utf-8') as f:
                        data = json.load(f)
                except json.JSONDecodeError as e:
                    errors.append(f'{name}: invalid JSON: {e}')
                    continue
                for key, value in data.items():
                    if key == '@@locale':
                        continue
                    if key in merged and merged[key] != value:
                        errors.append(f'Duplicate key "{key}" in {name} and {owners[key]}')
                        continue
                    merged[key] = value
                    owners[key] = name
            out = os.path.join(ARB_DIR, f'app_{locale}.arb')
            with open(out, 'w', encoding='utf-8') as f:
                json.dump(merged, f, ensure_ascii=False, indent=2)
                f.write('\n')
        if errors:
            print('\n'.join(errors), file=sys.stderr)
            return 1
        if '--no-gen' in sys.argv:
            return 0
        result = subprocess.run(['flutter', 'gen-l10n'], cwd=ROOT)
        return result.returncode


if __name__ == '__main__':
    sys.exit(main())
