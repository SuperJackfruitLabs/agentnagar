#!/usr/bin/env python3
"""Writes THIRD-PARTY-NOTICES.txt at the repository root: the licences of
everything third-party that ships inside an Agentnagar package.

  city/scripts/third_party_notices.py            write the file
  city/scripts/third_party_notices.py --check    fail if it is out of date
  city/scripts/third_party_notices.py --output F write somewhere else

A package holds three kinds of third-party material, and each has a section:

- the Godot engine, as the export template every package is built from
  (its LICENSE.txt and COPYRIGHT.txt, pinned in city/packaging/licenses/godot/
  at the release .github/workflows/package.yml installs);
- the Rust crates linked into the city-godot extension, read from
  city/Cargo.lock with `cargo tree` and `cargo metadata` (every platform,
  normal and build dependencies), with the licence files each crate
  publishes; godot-rust (MPL-2.0) is named with where its source is, and
  the MPL-2.0 text comes from city/packaging/licenses/MPL-2.0.txt;
- the fonts the style packs bundle (city/godot/styles/*/assets/fonts/),
  with the licence file beside each (a font without one stops the script);
- the Rust standard library the extension links, and the Emscripten runtime
  of the web build, with licence files pinned in city/packaging/licenses/.

Needs cargo and the crates' sources (cargo fetches them if they are missing).
The output names no local path, so it is the same on every machine.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

CITY = Path(__file__).resolve().parent.parent
ROOT = CITY.parent
OUTPUT = ROOT / 'THIRD-PARTY-NOTICES.txt'
GODOT_LICENCES = CITY / 'packaging' / 'licenses' / 'godot'
RUST_LICENCES = CITY / 'packaging' / 'licenses' / 'rust'
EMSCRIPTEN_LICENCE = CITY / 'packaging' / 'licenses' / 'emscripten' / 'LICENSE'
GODOT_TAG = '4.6.3-stable'
# The emscripten Godot's web templates were built with (.github/workflows/package.yml).
EMSCRIPTEN = '4.0.20'
# The oldest Rust release the workspace builds with (city/Cargo.toml rust-version).
RUST = '1.95.0'
SOURCE = 'https://github.com/SuperJackfruitLabs/agentnagar'
HOLDER = 'Super Jackfruit Labs (OPC) Private Limited'
EXTENSION = 'city-godot'
LICENCE_FILE = re.compile(r'^(licen[cs]e|copying|notice|unlicense|copyright)([-_.].*)?$', re.I)
RULE = '=' * 78
MIT_BODY = """Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""


def clean(text):
    """Text as it is printed: no byte-order mark, no trailing spaces, LF."""
    text = text.lstrip('﻿').replace('\r\n', '\n').replace('\r', '\n')
    return '\n'.join(line.rstrip() for line in text.split('\n')).strip('\n')


def read(path):
    return clean(path.read_text(encoding='utf-8', errors='replace'))


def heading(title):
    return [RULE, title, RULE, '']


def cargo(*args):
    return subprocess.run(['cargo', *args], cwd=CITY, check=True, capture_output=True, text=True).stdout


def shipped_crates():
    """(name, version) of every third-party crate in the extension, all platforms."""
    tree = cargo('tree', '--locked', '-p', EXTENSION, '-e', 'normal,build', '--target', 'all',
                 '--prefix', 'none', '-f', '{p}')
    crates = set()
    for line in tree.splitlines():
        match = re.match(r'^(\S+) v(\S+)(.*)$', line.strip())
        if match and '(/' not in match.group(3) and not re.search(r'\([A-Za-z]:', match.group(3)):
            crates.add((match.group(1), match.group(2)))
    return crates


def metadata():
    data = json.loads(cargo('metadata', '--locked', '--format-version', '1'))
    return {(p['name'], p['version']): p for p in data['packages']}


def licence_files(package):
    folder = Path(package['manifest_path']).parent
    return sorted((p for p in folder.iterdir() if p.is_file() and LICENCE_FILE.match(p.name)),
                  key=lambda p: p.name.lower())


def is_godot_rust(package):
    repo = (package.get('repository') or '').rstrip('/')
    return repo.endswith('godot-rust/gdext')


def godot_section():
    folder = GODOT_LICENCES
    lines = heading(f'1. Godot Engine {GODOT_TAG}')
    lines += [
        'Every Agentnagar package is built from the Godot Engine export template,',
        'so it contains the Godot Engine and the third-party components Godot',
        'builds into its templates. Godot is MIT-licensed; its COPYRIGHT.txt,',
        'reproduced after the licence, names each component with its licence and',
        'ends with the full text of every licence it uses (FreeType, mbed TLS,',
        'ENet, zstd, libpng, HarfBuzz, ICU and the rest).',
        '',
        f'Source: https://github.com/godotengine/godot/tree/{GODOT_TAG}',
        '',
        '-' * 78, 'Godot Engine LICENSE.txt', '-' * 78, '',
        read(folder / 'LICENSE.txt'), '',
        '-' * 78, 'Godot Engine COPYRIGHT.txt', '-' * 78, '',
        read(folder / 'COPYRIGHT.txt'), '',
    ]
    return lines


def crate_sections(crates, packages):
    godot_rust, others = [], []
    for key in sorted(crates):
        package = packages.get(key)
        if package is None:
            sys.exit(f'third_party_notices: {key[0]} {key[1]} is in the tree but not in cargo metadata')
        (godot_rust if is_godot_rust(package) else others).append(package)

    lines = heading('2. godot-rust (gdext)')
    lines += [
        'The city-godot extension is built with godot-rust, used unmodified from',
        'crates.io. These crates are licensed under the Mozilla Public License 2.0',
        '(text below). Their source code is available from crates.io, at the',
        'versions listed, and from https://github.com/godot-rust/gdext.',
        '',
    ]
    for package in godot_rust:
        lines.append(f'  {package["name"]} {package["version"]}  ({package["license"]})'
                     f'  https://crates.io/crates/{package["name"]}/{package["version"]}')
    lines += ['', '-' * 78, 'Mozilla Public License Version 2.0', '-' * 78, '', read(GODOT_LICENCES.parent / 'MPL-2.0.txt'), '']

    lines += heading('3. Rust crates in the city-godot extension')
    lines += [
        'The extension also statically links the Rust standard library (std,',
        'core, alloc and the crates they build on) of the Rust release it is',
        f'compiled with ({RUST} or later): Copyright The Rust Project Contributors,',
        'licensed MIT OR Apache-2.0. Its licence files follow; its COPYRIGHT file',
        f'lists the components: https://github.com/rust-lang/rust/blob/{RUST}/COPYRIGHT',
        '',
        '-' * 78, f'Rust standard library {RUST}: LICENSE-MIT', '-' * 78, '',
        read(RUST_LICENCES / 'LICENSE-MIT'), '',
        '-' * 78, f'Rust standard library {RUST}: LICENSE-APACHE', '-' * 78, '',
        read(RUST_LICENCES / 'LICENSE-APACHE'), '',
        'The extension library (libcity_godot / city_godot) is built from these',
        'crates, unmodified from crates.io: linked into it, or run while it is',
        'compiled (macros and build scripts). Where a crate offers a choice of',
        'licences ("A OR B"), every licence file it publishes is reproduced.',
        '',
    ]
    for package in others:
        authors = ', '.join(re.sub(r'\s*<[^>]*>', '', a) for a in package.get('authors') or []) or 'its authors'
        lines.append(f'  {package["name"]} {package["version"]}  ({package["license"]})')
        lines.append(f'    by {authors}')
        if package.get('repository'):
            lines.append(f'    {package["repository"]}')
    lines.append('')

    # Identical licence texts are printed once, naming every crate they cover.
    texts, order = {}, []
    for package in others:
        label = f'{package["name"]} {package["version"]}'
        files = licence_files(package)
        if files:
            found = [(f.name, read(f)) for f in files]
        elif 'MIT' in (package.get('license') or ''):
            authors = ', '.join(re.sub(r'\s*<[^>]*>', '', a) for a in package.get('authors') or []) or 'its authors'
            found = [('MIT (the crate publishes no licence file; the standard text with its authors)',
                      f'MIT License\n\nCopyright (c) {authors}\n\n{MIT_BODY}')]
        else:
            sys.exit(f'third_party_notices: {label} ({package.get("license")}) publishes no licence file')
        for name, text in found:
            digest = hashlib.sha256(text.encode()).hexdigest()
            if digest not in texts:
                texts[digest] = {'text': text, 'uses': []}
                order.append(digest)
            texts[digest]['uses'].append(f'{label} ({name})')
    for number, digest in enumerate(order, 1):
        entry = texts[digest]
        lines += ['-' * 78, f'3.{number}. Applies to:']
        lines += [f'  {use}' for use in entry['uses']]
        lines += ['-' * 78, '', entry['text'], '']
    return lines


def font_section():
    lines = heading('4. Fonts')
    lines += [
        'The style packs bundle these fonts. Each is used under the licence',
        'reproduced with it, which also travels beside the font inside every',
        'package. The fonts are not sold on their own.',
        '',
    ]
    fonts_dirs = sorted((CITY / 'godot' / 'styles').glob('*/assets/fonts'))
    # Every bundled font file must have its licence beside it, or it would be
    # missed here silently.
    for font in sorted(f for d in fonts_dirs for pattern in ('*.ttf', '*.otf', '*.woff', '*.woff2')
                       for f in d.glob(pattern)):
        family = font.name.split('-')[0]
        if not (font.parent / f'{family}-OFL.txt').exists():
            sys.exit(f'third_party_notices: {font.relative_to(CITY)} has no {family}-OFL.txt beside it; '
                     'add its licence (and extend this script if it is not the OFL)')
    for licence in sorted(f for d in fonts_dirs for f in d.glob('*-OFL.txt')):
        family = licence.name[:-len('-OFL.txt')]
        fonts = sorted(p.name for p in licence.parent.iterdir()
                       if p.name.startswith(f'{family}-') and p.suffix in ('.ttf', '.otf', '.woff', '.woff2'))
        pack = licence.parent.parent.parent.name
        lines += ['-' * 78, f'{family}: {", ".join(fonts)} (style pack {pack})',
                  'SIL Open Font License 1.1', '-' * 78, '', read(licence), '']
    return lines


def platform_section():
    lines = heading('5. Platform components')
    lines += [
        'Some packages also contain parts of the platform Godot exports to:',
        '',
        '- Android: the Godot Android library (MIT, section 1) and the AndroidX',
        '  and other Android support libraries Godot depends on, under the Apache',
        '  License 2.0 (text in section 3).',
        f'- Web: the Emscripten {EMSCRIPTEN} runtime that Godot\'s web template and',
        '  the extension are built with, under the MIT licence and the University',
        '  of Illinois/NCSA Open Source License; its licence file follows.',
        '',
        '-' * 78, f'Emscripten {EMSCRIPTEN} LICENSE', '-' * 78, '',
        read(EMSCRIPTEN_LICENCE), '',
        'Material in the Agentnagar repository that no package contains (the',
        'style-study web fonts, the vendored three.js used by the documentation',
        'pages) keeps its licence file beside it in the repository; see COPYING.md.',
        '',
    ]
    return lines


def render():
    crates = shipped_crates()
    packages = metadata()
    lines = [
        'Agentnagar: third-party notices',
        '',
        'Generated by city/scripts/third_party_notices.py; do not edit by hand.',
        '',
        f'Agentnagar is Copyright {HOLDER} and contributors. It is free',
        'software: you can redistribute it and/or modify it under the terms of the',
        'GNU Affero General Public License, version 3 only (LICENSE.txt in a',
        'package, LICENSE in the source). It comes',
        'with NO WARRANTY. Its source code is at',
        f'{SOURCE}',
        '',
        'Agentnagar packages also contain the third-party software and fonts',
        'below, each under its own licence:',
        '',
        f'  1. Godot Engine {GODOT_TAG}',
        '  2. godot-rust (gdext)',
        '  3. Rust crates in the city-godot extension',
        '  4. Fonts',
        '  5. Platform components',
        '',
    ]
    lines += godot_section()
    lines += crate_sections(crates, packages)
    lines += font_section()
    lines += platform_section()
    return '\n'.join(lines).rstrip('\n') + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--check', action='store_true', help='fail if the file is not what would be written')
    parser.add_argument('--output', type=Path, default=OUTPUT, help='the file to write or check')
    args = parser.parse_args(argv)
    text = render()
    if args.check:
        current = args.output.read_text(encoding='utf-8') if args.output.exists() else ''
        if current != text:
            print(f'third_party_notices: {args.output.name} is out of date; run city/scripts/third_party_notices.py',
                  file=sys.stderr)
            return 1
        print(f'third_party_notices: {args.output.name} is current')
        return 0
    args.output.write_text(text, encoding='utf-8')
    print(f'third_party_notices: wrote {args.output} ({len(text.encode()) // 1024} KiB)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
