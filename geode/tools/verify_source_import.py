#!/usr/bin/env python3
"""Verify preserved non-Kotlin source files against their original Git blob IDs."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'docs/source-import-manifest.json').read_text())
adapted = set(manifest['integration_files'])
failures = []
verified = 0
for entry in manifest['expected_original_files']:
    path = root / entry['path']
    if not path.is_file():
        failures.append(f"Missing: {entry['path']}")
        continue
    if entry['path'] in adapted:
        continue
    data = path.read_bytes()
    blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if blob != entry['original_blob']:
        failures.append(f"Changed original: {entry['path']}")
    else:
        verified += 1
if failures:
    raise SystemExit('\n'.join(failures))
print(f'{verified} non-Kotlin source files preserved byte-for-byte; '
      f'{len(adapted)} documented Flutter integration differences.')
