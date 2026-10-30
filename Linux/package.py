#!/usr/bin/env python3
"""Package Linux tooling only. Deliberately excludes third-party binary payload."""
import argparse
import hashlib
from pathlib import Path
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    names = ['README.md', 'REVIEW_NOTES.md', 'BUILD_INSTRUCTIONS.md',
             'DistributionScripts/manifest.json']
    names += ['Linux/' + name for name in ('gunlast.py', 'manifest.json', 'README.ru.md',
                                           'package.py', 'tests/test_gunlast.py')]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(args.output, 'w:gz') as archive:
        for name in names:
            archive.add(root / name, arcname='gunlast-linux-tools/' + name)
    checksum = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.output.with_suffix(args.output.suffix + '.sha256').write_text(
        checksum + '  ' + args.output.name + '\n')
    print(args.output)
    print(checksum)


if __name__ == '__main__':
    main()
