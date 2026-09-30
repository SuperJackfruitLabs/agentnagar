"""Exercise preservation and generated navigation on a small real filesystem."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import struct
import zlib
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/style_studies.py'
SPEC = importlib.util.spec_from_file_location('style_studies', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC) if SCRIPT.exists() else None
if MODULE:
    SPEC.loader.exec_module(MODULE)

SHEETS = ('00-city-perspectives', '01-living-community', '02-creating-exploring', '03-interfaces-perspectives')
def png_chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


PNG = (b'\x89PNG\r\n\x1a\n'
       + png_chunk(b'IHDR', struct.pack('>IIBBBBB', 1536, 1024, 8, 0, 0, 0, 0))
       + png_chunk(b'IDAT', zlib.compress(bytes(1537 * 1024)))
       + png_chunk(b'IEND', b''))


def digest(data):
    return hashlib.sha256(data).hexdigest()


class StyleStudiesTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(MODULE, 'style-study validation tool is not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.collection = self.root / 'docs/vision/style-studies'
        self.style = self.collection / 'styles/01-graphic'
        self.manifest = {'schema_version': 1, 'id': '01-graphic', 'name': 'Graphic',
                         'selected': dict.fromkeys(SHEETS, 'r001'),
                         'review_summary': 'Review pending; selection is not approval.',
                         'review_sources': ['history/review.md']}
        self.put(self.style / 'brief.md', '# Brief\n')
        self.put(self.style / 'history/review.md', '# Historical review\n')
        for path in ('shared/CONSISTENCY-CONTRACT.md', 'shared/sheet-program.md', 'shared/STRUCTURE.md', 'reviews/README.md', 'comparisons/README.md', 'pages.html'):
            self.put(self.collection / path, '# Reference\n')
        entries = []
        for sheet in SHEETS:
            revision = self.style / 'sheets' / sheet / 'r001'
            old = f'docs/vision/style-studies/01-graphic/{sheet}.png'
            self.put(revision / 'image.png', PNG)
            self.put(revision / 'prompt.txt', b'Exact prompt.  \r\n\n')
            self.put(revision / 'review.md', '# Pending review\n')
            self.json(revision / 'generation.json', {'schema_version': 1, 'sha256': digest(PNG), 'width': 1536, 'height': 1024,
                'prompt': {'status': 'saved', 'path': 'prompt.txt', 'sha256': digest(b'Exact prompt.  \r\n\n')},
                'source_paths': [old], 'reference_images': [], 'legacy_records': [], 'baseline_commit': 'abc123'})
            entries.append({'old_path': old, 'new_path': str((revision / 'image.png').relative_to(self.root)), 'sha256': digest(PNG)})
        self.ledger_path = self.collection / 'reviews/migration-2026-09-20.json'
        self.ledger = {'schema_version': 1, 'baseline_commit': 'abc123', 'files': entries,
                       'selected_at_migration': {entry['old_path']: entry['new_path'] for entry in entries}}
        self.json(self.ledger_path, self.ledger)
        self.json(self.style / 'manifest.json', self.manifest)
        MODULE.write_galleries(self.root)

    def put(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data.encode() if isinstance(data, str) else data)

    def json(self, path, data):
        self.put(path, json.dumps(data))

    def errors(self):
        return '\n'.join(MODULE.validate(self.root, expected_styles=1))

    def revision(self):
        return self.style / 'sheets' / SHEETS[0] / 'r001'

    def metadata(self, change):
        path = self.revision() / 'generation.json'
        data = json.loads(path.read_text())
        change(data)
        self.json(path, data)

    def test_valid_fixture_and_generated_selection_navigation(self):
        self.assertEqual('', self.errors())
        gallery = (self.style / 'README.md').read_text()
        self.assertIn('sheets/00-city-perspectives/r001/image.png', gallery)
        self.assertIn('Review pending; selection is not approval.', gallery)
        self.assertIn('history/review.md', gallery)

    def test_missing_selected_revision_is_rejected(self):
        self.manifest['selected'][SHEETS[0]] = 'r999'
        self.json(self.style / 'manifest.json', self.manifest)
        self.assertIn('selected revision', self.errors())

    def test_mutated_image_bytes_are_rejected(self):
        self.put(self.revision() / 'image.png', PNG + b'changed')
        self.assertIn('image SHA-256', self.errors())

    def test_prompt_whitespace_mutation_is_rejected(self):
        self.put(self.revision() / 'prompt.txt', b'Exact prompt.\n')
        self.assertIn('prompt SHA-256', self.errors())

    def test_missing_prompt_is_explicit_and_allowed(self):
        (self.revision() / 'prompt.txt').unlink()
        self.metadata(lambda d: d.update(prompt={'status': 'missing', 'path': None, 'sha256': None}))
        MODULE.write_galleries(self.root)
        self.assertEqual('', self.errors())
        self.assertIn('missing', (self.style / 'README.md').read_text())

    def test_claimed_saved_prompt_must_exist(self):
        (self.revision() / 'prompt.txt').unlink()
        self.assertIn('prompt.txt', self.errors())

    def test_dimension_mismatch_is_rejected(self):
        self.metadata(lambda d: d.update(width=25))
        self.assertIn('dimensions', self.errors())

    def test_duplicate_style_id_is_rejected(self):
        shutil.copytree(self.style, self.collection / 'styles/02-other')
        self.assertIn('duplicate style id', self.errors())

    def test_generated_gallery_staleness_is_rejected(self):
        self.put(self.style / 'README.md', '# Obsolete gallery\n')
        self.assertIn('stale generated gallery', self.errors())

    def page_data(self):
        text = (self.collection / 'shared/page-kit/styles-data.js').read_text()
        prefix = 'window.STYLE_DATA = '
        return json.loads(text[text.index(prefix) + len(prefix):].rstrip().rstrip(';'))

    def test_page_data_follows_manifest_selection(self):
        style = self.page_data()['styles'][0]
        self.assertEqual('01-graphic', style['id'])
        self.assertEqual('Review pending; selection is not approval.', style['review_summary'])
        self.assertEqual('styles/01-graphic/sheets/00-city-perspectives/r001/image.png', style['sheets'][0]['image'])
        self.assertEqual(['styles/01-graphic/history/review.md'], style['review_sources'])
        self.assertEqual(('01-graphic', '01-graphic'), (style['prev'], style['next']))

    def test_root_gallery_links_showcase_index(self):
        self.assertIn('[Style showcase pages](pages.html)', (self.collection / 'README.md').read_text())

    def test_stale_page_data_is_rejected(self):
        self.put(self.collection / 'shared/page-kit/styles-data.js', 'window.STYLE_DATA = {};\n')
        self.assertIn('stale generated gallery', self.errors())

    def test_broken_repository_markdown_link_is_rejected(self):
        self.put(self.root / 'notes.md', '[Broken](missing.md)\n')
        self.assertIn('missing.md', self.errors())

    def test_markdown_code_and_external_links_are_not_local_paths(self):
        self.put(self.root / 'notes.md', '[Remote](https://example.test/no-file)\n`[example](not-a-file.md)`\n```md\n[example](also-not-a-file.md)\n```\n')
        self.assertEqual('', self.errors())

    def test_source_snapshot_links_are_not_interpreted(self):
        self.put(self.style / 'history/original.source.txt', '[Old](obsolete.png)\n')
        self.assertEqual('', self.errors())

    def test_unselected_revisions_are_checked(self):
        other = self.revision().with_name('r002')
        shutil.copytree(self.revision(), other)
        self.put(other / 'image.png', b'broken')
        MODULE.write_galleries(self.root)
        self.assertIn('image SHA-256', self.errors())

    def test_provenance_must_have_sources(self):
        self.metadata(lambda d: d.update(source_paths=[]))
        self.assertIn('source_paths', self.errors())

    def test_reference_images_must_exist(self):
        self.metadata(lambda d: d.update(reference_images=['missing-reference.png']))
        self.assertIn('missing-reference.png', self.errors())

    def test_ledger_preserved_bytes_are_verified(self):
        self.ledger['files'][0]['sha256'] = '0' * 64
        self.json(self.ledger_path, self.ledger)
        self.assertIn('ledger SHA-256', self.errors())

    def test_a_text_record_may_be_redacted_with_its_reason_and_hash(self):
        record = self.style / 'history/outputs.json'
        self.put(record, '{"source": "/home/someone/output.png"}\n')
        entry = {'old_path': 'docs/vision/style-studies/outputs.json',
                 'new_path': str(record.relative_to(self.root)),
                 'sha256': digest(b'{"source": "/home/someone/output.png"}\n')}
        self.ledger['files'].append(entry)
        self.json(self.ledger_path, self.ledger)
        self.assertEqual('', self.errors())
        redacted = b'{"source": "<home>/output.png"}\n'
        self.put(record, redacted)
        self.assertIn('ledger SHA-256', self.errors())
        entry['redaction'] = {'reason': 'local paths removed', 'sha256': digest(redacted)}
        self.json(self.ledger_path, self.ledger)
        self.assertEqual('', self.errors())
        self.put(record, redacted + b' ')
        self.assertIn('ledger SHA-256', self.errors())
        self.put(record, redacted)
        entry['redaction'] = {'sha256': digest(redacted)}
        self.json(self.ledger_path, self.ledger)
        self.assertIn('invalid redaction', self.errors())

    def test_an_image_cannot_be_redacted(self):
        self.ledger['files'][0]['redaction'] = {'reason': 'cropped', 'sha256': digest(PNG)}
        self.json(self.ledger_path, self.ledger)
        self.assertIn('an image cannot be redacted', self.errors())

    def test_future_revision_can_be_selected_while_baseline_is_preserved(self):
        other = self.revision().with_name('r002')
        shutil.copytree(self.revision(), other)
        self.put(other / 'image.png', PNG + b'other')
        data = json.loads((other / 'generation.json').read_text())
        data['sha256'] = digest(PNG + b'other')
        data['baseline_commit'] = None
        data['source_paths'] = ['imagegen-output:2026-09-21/candidate-1.png']
        self.json(other / 'generation.json', data)
        self.manifest['selected'][SHEETS[0]] = 'r002'
        self.json(self.style / 'manifest.json', self.manifest)
        MODULE.write_galleries(self.root)
        self.assertEqual('', self.errors())
        self.put(self.revision() / 'image.png', PNG + b'tampered historical image')
        self.assertIn('ledger SHA-256', self.errors())

    def test_git_baseline_file_omission_is_rejected(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        old = self.collection / 'lost-record.txt'
        self.put(old, 'Preserve this original record.\n')
        subprocess.run(['git', '-C', str(self.root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'baseline'], check=True)
        commit = subprocess.check_output(['git', '-C', str(self.root), 'rev-parse', 'HEAD'], text=True).strip()
        self.ledger['baseline_commit'] = commit
        self.json(self.ledger_path, self.ledger)
        self.assertIn('baseline file absent from ledger', self.errors())

    def test_absent_git_baseline_commit_skips_only_the_git_cross_check(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'squashed'], check=True)
        # The fixture ledger names 'abc123', which this clone does not contain.
        self.assertEqual('', self.errors())
        self.put(self.revision() / 'image.png', PNG + b'tampered')
        self.assertIn('ledger SHA-256', self.errors())

    def test_missing_prompt_schema_requires_explicit_null_fields(self):
        (self.revision() / 'prompt.txt').unlink()
        self.metadata(lambda d: d.update(prompt={'status': 'missing'}))
        MODULE.write_galleries(self.root)
        self.assertIn('prompt schema', self.errors())

    def test_broken_reference_style_markdown_link_is_rejected(self):
        self.put(self.root / 'notes.md', '[Reference][missing]\n\n[missing]: nowhere.md\n')
        self.assertIn('nowhere.md', self.errors())

    def test_prose_label_followed_by_table_is_not_link_definition(self):
        self.put(self.root / 'notes.md', '[verified]:\n\n| Version | Date |\n| --- | --- |\n')
        self.assertEqual('', self.errors())

    def test_malformed_manifest_id_returns_validation_error(self):
        self.manifest['id'] = ['not-an-id']
        self.json(self.style / 'manifest.json', self.manifest)
        self.assertIn('style id', self.errors())

    def test_malformed_ledger_files_returns_validation_error(self):
        self.ledger['files'] = {'old_path': 'wrong shape'}
        self.json(self.ledger_path, self.ledger)
        self.assertIn('files must be an array', self.errors())

    def test_malformed_ledger_entry_returns_validation_error(self):
        self.ledger['files'].append(None)
        self.json(self.ledger_path, self.ledger)
        self.assertIn('ledger entry must be an object', self.errors())

    def test_cross_repository_links_are_outside_local_link_validation(self):
        self.put(self.root / 'docs/notes.md', '[Sibling](../../other-repository/README.md)\n[Local](missing.md)\n')
        errors = self.errors()
        self.assertNotIn('other-repository', errors)
        self.assertIn('missing.md', errors)

    def test_collection_links_images_without_loading_full_collection(self):
        gallery = (self.collection / 'README.md').read_text()
        self.assertIn('[r001](styles/01-graphic/sheets/00-city-perspectives/r001/image.png)', gallery)
        self.assertNotIn('![', gallery)
        self.assertEqual(4, (self.style / 'README.md').read_text().count('!['))

    def test_migration_selection_record_cannot_redirect_original_artwork(self):
        original = self.ledger['files'][0]['old_path']
        self.ledger['selected_at_migration'][original] = self.ledger['files'][1]['new_path']
        self.json(self.ledger_path, self.ledger)
        self.assertIn('migration selection destination', self.errors())

    def test_migrated_source_cannot_claim_unrelated_preserved_bytes(self):
        old = 'docs/vision/style-studies/unrelated.png'
        other = self.collection / 'reviews/unrelated.png'
        self.put(other, PNG + b'unrelated preserved image')
        self.ledger['files'].append({'old_path': old, 'new_path': str(other.relative_to(self.root)),
                                     'sha256': digest(other.read_bytes())})
        self.json(self.ledger_path, self.ledger)
        self.metadata(lambda d: d.update(source_paths=[old]))
        self.assertIn('source provenance SHA-256', self.errors())

    def test_migrated_source_must_resolve_to_its_revision_image(self):
        other_source = self.ledger['files'][1]['old_path']
        self.metadata(lambda d: d.update(source_paths=[other_source]))
        self.assertIn('source provenance destination', self.errors())

    def test_matching_metadata_does_not_allow_wrong_sheet_dimensions(self):
        small = (b'\x89PNG\r\n\x1a\n'
                 + png_chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 0, 0, 0, 0))
                 + png_chunk(b'IDAT', zlib.compress(b'\0\0'))
                 + png_chunk(b'IEND', b''))
        self.put(self.revision() / 'image.png', small)
        self.metadata(lambda d: d.update(width=1, height=1, sha256=digest(small)))
        self.assertIn('sheet dimensions must be 1536x1024', self.errors())

    def archived_prompt(self):
        wrapper = b'# Original prompt\n\nArchived commentary.\n\n```text\nExact prompt.  \r\n\n```\n'
        self.put(self.style / 'history/initial-prompt.source.txt', wrapper)
        self.metadata(lambda d: d.update(prompt_source={
            'path': '../../../history/initial-prompt.source.txt',
            'format': 'markdown-fenced-text', 'sha256': digest(wrapper)}))
        MODULE.write_galleries(self.root)

    def test_archived_fenced_prompt_is_verified_and_labeled(self):
        self.archived_prompt()
        self.assertEqual('', self.errors())
        self.assertIn('[Archived prompt]', (self.style / 'README.md').read_text())

    def test_archived_prompt_canonical_payload_cannot_be_changed(self):
        self.archived_prompt()
        self.put(self.revision() / 'prompt.txt', b'Altered prompt.\n')
        self.metadata(lambda d: d['prompt'].update(sha256=digest(b'Altered prompt.\n')))
        self.assertIn('archived prompt payload', self.errors())

    def test_archived_prompt_wrapper_hash_is_verified(self):
        self.archived_prompt()
        self.put(self.style / 'history/initial-prompt.source.txt', b'# changed wrapper\n')
        self.assertIn('prompt source SHA-256', self.errors())

    def test_archived_prompt_requires_one_text_block(self):
        self.archived_prompt()
        wrapper_path = self.style / 'history/initial-prompt.source.txt'
        wrapper = wrapper_path.read_bytes() + b'\n```text\nSecond prompt.\n```\n'
        self.put(wrapper_path, wrapper)
        self.metadata(lambda d: d['prompt_source'].update(sha256=digest(wrapper)))
        self.assertIn('exactly one fenced text block', self.errors())


if __name__ == '__main__':
    unittest.main()
