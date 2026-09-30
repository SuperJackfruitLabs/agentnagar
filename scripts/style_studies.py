#!/usr/bin/env python3
"""Render and verify the style-study archive using only the Python standard library."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
from urllib.parse import unquote, urlsplit

COLLECTION = Path('docs/vision/style-studies')
SHEETS = ('00-city-perspectives', '01-living-community', '02-creating-exploring', '03-interfaces-perspectives')
LEDGER = Path('reviews/migration-2026-09-20.json')
REVISION = re.compile(r'r\d{3}')
PAGE_DATA = Path('shared/page-kit/styles-data.js')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def title(sheet):
    return sheet[3:].replace('-', ' ').capitalize()


def has_openai_credentials(path):
    """Whether a PNG carries OpenAI's C2PA content credentials (a caBX chunk naming OpenAI)."""
    try:
        data = path.read_bytes()
    except OSError:
        return False
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        return False
    at = 8
    while at + 8 <= len(data):
        size = struct.unpack('>I', data[at:at + 4])[0]
        kind = data[at + 4:at + 8]
        if kind == b'caBX' and b'OpenAI' in data[at + 8:at + 8 + size]:
            return True
        at += 12 + size
    return False


def generator_record(style):
    """(credentialed, total) sheet images of a style folder."""
    images = sorted(style.glob('sheets/*/r[0-9][0-9][0-9]/image.png'))
    return sum(1 for image in images if has_openai_credentials(image)), len(images)


def generator_note(style):
    """What the records show about a style's image generator, as a phrase."""
    credentialed, total = generator_record(style)
    if total and credentialed == total:
        return "OpenAI gpt-image, per the C2PA content credentials every sheet image carries"
    if credentialed:
        return (f"OpenAI gpt-image for the {credentialed} of {total} sheet images that carry its C2PA content "
                "credentials; the generator was not recorded for the others")
    return "the generator was not recorded"


def sheet_generator(image):
    return 'OpenAI gpt-image (C2PA credentials)' if has_openai_credentials(image) else 'not recorded'


def manifests(root):
    return [(path, read_json(path)) for path in sorted((root / COLLECTION / 'styles').glob('*/manifest.json'))]


def render_galleries(root):
    """Return deterministic output paths and text without changing the archive."""
    collection = root / COLLECTION
    styles = manifests(root)
    outputs = {}
    lines = ['# City visual style studies', '',
             'Concept illustrations for design exploration; these are not game captures or implementation evidence.', '',
             '**The sheet images are AI-generated and released under CC0 1.0; see '
             '[AI-generated images](#ai-generated-images).**', '',
             'Manifest selections define the current gallery. Selection does not imply review approval.', '',
             '[Style showcase pages](pages.html): one page per style, each built in that style.', '',
             '[Consistency contract](shared/CONSISTENCY-CONTRACT.md) · [Sheet program](shared/sheet-program.md) · '
             '[Structure and authoring](shared/STRUCTURE.md) · [Reviews](reviews/README.md) · [Comparisons](comparisons/README.md)', '',
             '| Style | ' + ' | '.join(title(sheet) for sheet in SHEETS) + ' | Review summary |',
             '| --- | ' + ' | '.join('---' for _ in SHEETS) + ' | --- |']
    records = {path.parent.name: generator_record(path.parent) for path, _ in styles}
    full = [name[:2] for name, (c, n) in records.items() if n and c == n]
    partial = [name[:2] for name, (c, n) in records.items() if 0 < c < n]
    unrecorded = [name[:2] for name, (c, n) in records.items() if not c]
    notice = ['', '## AI-generated images', '',
              'Every sheet image in this collection (`styles/*/sheets/*/r*/image.png`) and both '
              '[comparison sheets](comparisons/README.md) are **AI-generated** concept art: not drawn by hand, '
              'and not game captures. They were generated in September 2026.', '',
              'Where an image still carries OpenAI\'s C2PA content credentials, it was made with OpenAI\'s image '
              'model (gpt-image), through ChatGPT or through an AI coding agent\'s built-in image tool '
              '(`image_gen`). Where it carries none, the generator was not recorded. Each style\'s page says which '
              'of its images carry the credentials:', '',
              f'- every image: styles {", ".join(full) or "none"}, and both comparison sheets;',
              f'- some images: styles {", ".join(partial) or "none"};',
              f'- no image (generator not recorded): styles {", ".join(unrecorded) or "none"}.', '',
              'They are concept studies for design exploration, not shipped game assets. The images are released '
              'under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) (`LICENSES/CC0-1.0.txt` at the '
              'repository root): no rights are claimed. The prompts, briefs, reviews and records beside them are '
              'documentation under CC BY-SA 4.0; see `COPYING.md` at the repository root.']
    for path, manifest in styles:
        style = path.parent
        name = manifest['name']
        selected = manifest['selected']
        summary = manifest['review_summary']
        cells = [f'[{name}](styles/{style.name}/README.md)']
        for sheet in SHEETS:
            image = f'styles/{style.name}/sheets/{sheet}/{selected[sheet]}/image.png'
            cells.append(f'[{selected[sheet]}]({image})')
        cells.append(summary.replace('|', '\\|').replace('\n', ' '))
        lines.append('| ' + ' | '.join(cells) + ' |')
        page = [f'# {name}', '', '[Collection](../../README.md) · [Brief](brief.md) · [Manifest](manifest.json)', '',
                summary, '', 'Selection does not imply review approval.', '',
                f'The sheet images are AI-generated concept art ({generator_note(style)}), not game captures, '
                'released under CC0 1.0 with no rights claimed; see '
                '[AI-generated images](../../README.md#ai-generated-images).',
                '', '## Review sources', '']
        if manifest['review_sources']:
            page.extend(f'- [{Path(source).name}]({source})' for source in manifest['review_sources'])
        else:
            page.append('No review sources recorded.')
        page.extend(['', '## Current selections', ''])
        for sheet in SHEETS:
            revision = selected[sheet]
            base = f'sheets/{sheet}/{revision}'
            generation = read_json(style / base / 'generation.json')
            prompt = generation['prompt']
            prompt_label = 'Archived prompt' if 'prompt_source' in generation else 'Exact prompt'
            prompt_link = f'[{prompt_label}]({base}/prompt.txt)' if prompt['status'] == 'saved' else 'Exact prompt: missing'
            page.extend([f'### {title(sheet)} — {revision}', '', f'![{name} — {title(sheet)}]({base}/image.png)', '',
                         f'{prompt_link} · [Generation record]({base}/generation.json) · [Review]({base}/review.md) · '
                         f'Generator: {sheet_generator(style / base / "image.png")}', ''])
        page.extend(['## Revision history', '', 'Revision numbers record migration ordering, not generation timestamps.', ''])
        for sheet in SHEETS:
            for revision in sorted((style / 'sheets' / sheet).glob('r[0-9][0-9][0-9]')):
                base = revision.relative_to(style).as_posix()
                chosen = ' — selected' if revision.name == selected[sheet] else ''
                page.append(f'- {title(sheet)} / {revision.name}{chosen}: [image]({base}/image.png), '
                            f'[generation]({base}/generation.json), [review]({base}/review.md)')
        outputs[style / 'README.md'] = '\n'.join(page) + '\n'
    outputs[collection / 'README.md'] = '\n'.join(lines + notice) + '\n'
    outputs[collection / PAGE_DATA] = render_page_data(styles)
    return outputs


def render_page_data(styles):
    """Selections for the style showcase pages; paths are relative to the collection root."""
    ids = [manifest['id'] for _, manifest in styles]
    entries = []
    for index, (path, manifest) in enumerate(styles):
        base = f'styles/{path.parent.name}'
        entries.append({
            'id': manifest['id'], 'name': manifest['name'],
            'number': path.parent.name[:2], 'slug': path.parent.name[3:],
            'readme': f'{base}/README.md', 'brief': f'{base}/brief.md', 'manifest': f'{base}/manifest.json',
            'page': f'{base}/page/index.html',
            'review_summary': manifest['review_summary'],
            'generator_note': generator_note(path.parent),
            'review_sources': [f'{base}/{source}' for source in manifest['review_sources']],
            'sheets': [{'id': sheet, 'title': title(sheet), 'revision': manifest['selected'][sheet],
                        'image': f'{base}/sheets/{sheet}/{manifest["selected"][sheet]}/image.png',
                        'review': f'{base}/sheets/{sheet}/{manifest["selected"][sheet]}/review.md',
                        'generator': sheet_generator(path.parent / 'sheets' / sheet / manifest['selected'][sheet]
                                                     / 'image.png')} for sheet in SHEETS],
            'prev': ids[index - 1], 'next': ids[(index + 1) % len(ids)],
        })
    data = json.dumps({'styles': entries}, indent=1, ensure_ascii=False)
    return f'// Generated by scripts/style_studies.py --write; do not edit.\nwindow.STYLE_DATA = {data};\n'


def write_galleries(root):
    for path, content in render_galleries(Path(root)).items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')


def markdown_link_errors(root):
    """Check local inline/reference Markdown destinations, ignoring code and URLs."""
    root = Path(root).resolve()
    errors = []
    for path in sorted(root.rglob('*.md')):
        if any(part in {'.git', 'node_modules', '.venv', 'venv', '__pycache__'} for part in path.relative_to(root).parts):
            continue
        text = path.read_text(encoding='utf-8')
        text = re.sub(r'(?ms)^\s*(```|~~~).*?^\s*\1[^\n]*$', '', text)
        text = re.sub(r'(`+).*?\1', '', text, flags=re.S)
        targets = re.findall(r'\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)', text)
        targets += re.findall(r'(?m)^[ \t]*\[[^\]\n]+\]:[ \t]*(<[^>\n]+>|[^\s]+)', text)
        for target in targets:
            target = target.strip('<>')
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            local = unquote(parsed.path)
            destination = root / local.lstrip('/') if local.startswith('/') else path.parent / local
            # Workspace links into sibling repositories are outside this check.
            if not destination.resolve().is_relative_to(root):
                continue
            if not destination.exists():
                errors.append(f'{path.relative_to(root)}: broken local link: {target}')
    return errors


def validate(root, expected_styles=None, check_links=True):
    """Return all validation problems; fixtures may omit the production style count."""
    root = Path(root).resolve()
    collection = root / COLLECTION
    errors = []

    def problem(path, message):
        errors.append(f'{path.relative_to(root)}: {message}')

    def load(path):
        try:
            data = read_json(path)
            if not isinstance(data, dict):
                raise ValueError('expected JSON object')
            return data
        except (OSError, ValueError) as exc:
            problem(path, str(exc))
            return {}

    def exists(base, relative):
        if not isinstance(relative, str) or not relative:
            problem(base, 'expected nonempty relative path')
            return None
        target = (base / relative).resolve()
        if Path(relative).is_absolute() or not target.is_relative_to(root):
            problem(base, f'path escapes repository: {relative}')
            return None
        if not target.is_file():
            problem(base, f'missing file: {relative}')
            return None
        return target

    ledger_path = collection / LEDGER
    ledger = load(ledger_path)
    if ledger.get('schema_version') != 1:
        problem(ledger_path, 'unsupported ledger schema_version')
    entries = {}
    files = ledger.get('files')
    if not isinstance(files, list):
        problem(ledger_path, 'files must be an array')
        files = []
    for entry in files:
        if not isinstance(entry, dict):
            problem(ledger_path, 'ledger entry must be an object')
            continue
        old = entry.get('old_path')
        if not isinstance(old, str) or not old or old in entries:
            problem(ledger_path, f'invalid or duplicate old_path: {old}')
            continue
        entries[old] = entry
        target = exists(root, entry.get('new_path'))
        # `sha256` stays the preserved baseline bytes. A text record may later be
        # redacted (local paths removed, say); the redaction names its reason
        # and the redacted bytes' hash. Images are never redacted.
        expected = entry.get('sha256')
        redaction = entry.get('redaction')
        if redaction is not None:
            if (not isinstance(redaction, dict) or not isinstance(redaction.get('reason'), str)
                    or not redaction['reason'] or not isinstance(redaction.get('sha256'), str)):
                problem(ledger_path, f'invalid redaction: {old}')
            elif str(entry.get('new_path', '')).lower().endswith('.png'):
                problem(ledger_path, f'an image cannot be redacted: {old}')
            else:
                expected = redaction['sha256']
        if target and sha256(target) != expected:
            problem(target, 'ledger SHA-256 mismatch')
    initial_selections = ledger.get('selected_at_migration')
    if initial_selections is not None:
        if not isinstance(initial_selections, dict):
            problem(ledger_path, 'selected_at_migration must be an object')
            initial_selections = {}
        for old, destination in initial_selections.items():
            if old not in entries or destination != entries[old].get('new_path'):
                problem(ledger_path, f'migration selection destination differs from preservation ledger: {old}')
    # Git is optional for exported archives; in a checkout it proves the ledger
    # covers every baseline file and cannot silently redefine preserved bytes.
    baseline_commit = ledger.get('baseline_commit')
    check_git = (root / '.git').exists() and isinstance(baseline_commit, str)
    if check_git and subprocess.run(['git', '-C', str(root), 'cat-file', '-e', f'{baseline_commit}^{{commit}}'],
                                    capture_output=True).returncode != 0:
        # A squashed public history does not contain the pre-publication baseline
        # commit; the per-file SHA-256 ledger above still proves the preserved bytes.
        print(f'Note: baseline commit {baseline_commit[:12]} is not in this clone '
              '(pre-publication history); skipping the Git baseline cross-check.', file=sys.stderr)
        check_git = False
    if check_git:
        try:
            baseline = subprocess.run(
                ['git', '-C', str(root), 'ls-tree', '-r', '-z', ledger['baseline_commit'], '--', COLLECTION.as_posix()],
                check=True, capture_output=True).stdout
            baseline_paths = set()
            for record in baseline.split(b'\0'):
                if not record:
                    continue
                info, filename = record.split(b'\t', 1)
                old = filename.decode('utf-8')
                baseline_paths.add(old)
                entry = entries.get(old)
                if entry is None:
                    problem(ledger_path, f'baseline file absent from ledger: {old}')
                    continue
                blob = subprocess.run(['git', '-C', str(root), 'cat-file', 'blob', info.split()[2].decode()],
                                      check=True, capture_output=True).stdout
                if hashlib.sha256(blob).hexdigest() != entry.get('sha256'):
                    problem(ledger_path, f'ledger hash differs from Git baseline: {old}')
            for old in entries.keys() - baseline_paths:
                problem(ledger_path, f'ledger path absent from Git baseline: {old}')
        except (OSError, subprocess.CalledProcessError, ValueError) as exc:
            problem(ledger_path, f'cannot verify Git baseline: {exc}')
    paths = sorted((collection / 'styles').glob('*/manifest.json'))
    if expected_styles is not None and len(paths) != expected_styles:
        problem(collection, f'expected {expected_styles} style manifests, found {len(paths)}')
    ids = set()
    for path in paths:
        manifest = load(path)
        style = path.parent
        identifier = manifest.get('id')
        if not isinstance(identifier, str):
            problem(path, 'style id must be text')
            identifier = None
        if identifier in ids:
            problem(path, f'duplicate style id: {identifier}')
        ids.add(identifier)
        if identifier != style.name:
            problem(path, 'style id must match directory name')
        if manifest.get('schema_version') != 1:
            problem(path, 'unsupported manifest schema_version')
        for key in ('name', 'review_summary'):
            if not isinstance(manifest.get(key), str) or not manifest[key]:
                problem(path, f'{key} must be nonempty text')
        exists(style, 'brief.md')
        sources = manifest.get('review_sources')
        if not isinstance(sources, list):
            problem(path, 'review_sources must be an array')
        else:
            for source in sources:
                exists(style, source)
        selected = manifest.get('selected', {})
        if not isinstance(selected, dict) or set(selected) != set(SHEETS):
            problem(path, 'selected must map exactly the four sheet IDs')
            selected = selected if isinstance(selected, dict) else {}
        for sheet in SHEETS:
            revision_name = selected.get(sheet)
            if not isinstance(revision_name, str) or not REVISION.fullmatch(revision_name):
                problem(path, f'invalid selected revision for {sheet}')
                continue
            image = style / 'sheets' / sheet / revision_name / 'image.png'
            if not image.is_file():
                problem(path, f'missing selected revision for {sheet}: {revision_name}')
            baseline_path = (COLLECTION / style.name / f'{sheet}.png').as_posix()
            baseline = entries.get(baseline_path)
            if baseline is None:
                problem(path, f'missing baseline gallery ledger entry: {baseline_path}')
            elif initial_selections is not None and baseline_path not in initial_selections:
                problem(ledger_path, f'missing migration selection destination: {baseline_path}')
        for sheet_dir in sorted((style / 'sheets').iterdir()) if (style / 'sheets').is_dir() else []:
            if sheet_dir.name not in SHEETS or not sheet_dir.is_dir():
                problem(sheet_dir, 'unknown sheet')
                continue
            for revision in sorted(sheet_dir.iterdir()):
                if not revision.is_dir() or not REVISION.fullmatch(revision.name):
                    problem(revision, 'invalid revision directory')
                    continue
                metadata_path = revision / 'generation.json'
                data = load(metadata_path)
                if data.get('schema_version') != 1:
                    problem(metadata_path, 'unsupported generation schema_version')
                if 'baseline_commit' not in data or (data['baseline_commit'] is not None and data['baseline_commit'] != ledger.get('baseline_commit')):
                    problem(metadata_path, 'baseline_commit differs from migration ledger')
                image = exists(revision, 'image.png')
                exists(revision, 'review.md')
                if image:
                    if sha256(image) != data.get('sha256'):
                        problem(image, 'image SHA-256 mismatch')
                    header = image.read_bytes()[:24]
                    if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
                        problem(image, 'invalid PNG header')
                    else:
                        dimensions = struct.unpack('>II', header[16:24])
                        if dimensions != (data.get('width'), data.get('height')):
                            problem(image, 'PNG dimensions mismatch')
                        if dimensions != (1536, 1024):
                            problem(image, 'sheet dimensions must be 1536x1024')
                prompt = data.get('prompt', {})
                if not isinstance(prompt, dict):
                    problem(metadata_path, 'prompt must be an object')
                elif set(prompt) != {'status', 'path', 'sha256'}:
                    problem(metadata_path, 'prompt schema requires status, path and sha256')
                elif prompt.get('status') == 'saved':
                    if prompt.get('path') != 'prompt.txt':
                        problem(metadata_path, 'saved prompt path must be prompt.txt')
                    saved = exists(revision, 'prompt.txt')
                    if saved and sha256(saved) != prompt.get('sha256'):
                        problem(saved, 'prompt SHA-256 mismatch (exact bytes required)')
                elif prompt.get('status') == 'missing':
                    if prompt.get('path') is not None or prompt.get('sha256') is not None or (revision / 'prompt.txt').exists():
                        problem(metadata_path, 'missing prompt must have null path/hash and no prompt.txt')
                else:
                    problem(metadata_path, 'prompt status must be saved or missing')
                if 'prompt_source' in data:
                    source = data['prompt_source']
                    if not isinstance(source, dict) or set(source) != {'path', 'format', 'sha256'}:
                        problem(metadata_path, 'prompt_source requires path, format and sha256')
                    elif source['format'] != 'markdown-fenced-text':
                        problem(metadata_path, 'unsupported prompt_source format')
                    else:
                        wrapper = exists(revision, source['path'])
                        if wrapper:
                            wrapper_bytes = wrapper.read_bytes()
                            if hashlib.sha256(wrapper_bytes).hexdigest() != source['sha256']:
                                problem(wrapper, 'prompt source SHA-256 mismatch')
                            payloads = re.findall(rb'(?ms)^```text\r?\n(.*?)^```[ \t]*\r?$', wrapper_bytes)
                            if len(payloads) != 1:
                                problem(wrapper, 'prompt source must contain exactly one fenced text block')
                            elif not isinstance(prompt, dict) or prompt.get('status') != 'saved':
                                problem(metadata_path, 'archived prompt payload requires a saved canonical prompt')
                            elif not (revision / 'prompt.txt').is_file() or (revision / 'prompt.txt').read_bytes() != payloads[0]:
                                problem(metadata_path, 'archived prompt payload differs from canonical prompt bytes')
                source_paths = data.get('source_paths')
                if not isinstance(source_paths, list) or not source_paths or any(not isinstance(p, str) or not p for p in source_paths):
                    problem(metadata_path, 'source_paths must be a nonempty array of source identifiers')
                elif data.get('baseline_commit') is not None:
                    for source in source_paths:
                        if source not in entries:
                            problem(metadata_path, f'source_paths entry absent from ledger: {source}')
                            continue
                        entry = entries[source]
                        if entry.get('sha256') != data.get('sha256'):
                            problem(metadata_path, f'source provenance SHA-256 differs from revision image: {source}')
                        destination = entry.get('new_path')
                        if not isinstance(destination, str) or (root / destination).resolve() != (revision / 'image.png').resolve():
                            problem(metadata_path, f'source provenance destination differs from revision image: {source}')
                for key in ('reference_images', 'legacy_records'):
                    if not isinstance(data.get(key), list):
                        problem(metadata_path, f'{key} must be an array')
                    else:
                        for relative in data[key]:
                            exists(revision, relative)
    try:
        for path, content in render_galleries(root).items():
            if not path.exists() or path.read_bytes() != content.encode('utf-8'):
                problem(path, 'stale generated gallery; run scripts/style_studies.py --write')
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        problem(collection, f'cannot render galleries: {exc}')
    if check_links:
        errors.extend(markdown_link_errors(root))
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write', action='store_true', help='regenerate root and style galleries')
    mode.add_argument('--check', action='store_true', help='validate the collection and repository Markdown links')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1], help='repository root')
    args = parser.parse_args(argv)
    try:
        if args.write:
            write_galleries(args.root.resolve())
            print('Generated style-study galleries.')
            return 0
        errors = validate(args.root, expected_styles=30)
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
        print(f'Style-study error: {exc}', file=sys.stderr)
        return 1
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Style-study validation passed: 30 styles, selections, revisions, preservation, galleries and local links.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
