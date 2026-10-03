"""The asset studies' jobs match their data, and filing an image keeps its record straight."""
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

PACK = Path(__file__).resolve().parents[1] / 'docs/vision/asset-studies'
LABELS = ('Use case', 'Asset type', 'Primary request', 'Constraints', 'Avoid')


def png_chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def png(width, height):
    return (b'\x89PNG\r\n\x1a\n'
            + png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 0, 0, 0, 0))
            + png_chunk(b'IDAT', zlib.compress(bytes((width + 1) * height)))
            + png_chunk(b'IEND', b''))


def run(script, *args, cwd):
    return subprocess.run([sys.executable, str(Path(cwd) / 'tools' / script), *args], cwd=cwd, capture_output=True, text=True)


class AssetStudiesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.pack = Path(self.temp.name) / 'asset-studies'
        self.pack.mkdir()
        for name in ('data', 'tools'):
            shutil.copytree(PACK / name, self.pack / name, ignore=shutil.ignore_patterns('__pycache__'))

    def jobs(self):
        return json.loads((PACK / 'jobs/jobs.json').read_text())['jobs']

    def test_committed_jobs_are_what_the_data_gives(self):
        built = run('build_jobs.py', cwd=self.pack)
        self.assertEqual(built.returncode, 0, built.stderr)
        for path in ('jobs/jobs.json', 'JOBS.md', 'STYLES.md', 'SUBJECTS.md'):
            self.assertEqual((self.pack / path).read_text(), (PACK / path).read_text(), f'{path} is out of date: run tools/build_jobs.py')
        fresh = sorted(str(p.relative_to(self.pack)) for p in (self.pack / 'jobs').rglob('*.md'))
        kept = sorted(str(p.relative_to(PACK)) for p in (PACK / 'jobs').rglob('*.md'))
        self.assertEqual(fresh, kept)
        for path in fresh:
            self.assertEqual((self.pack / path).read_text(), (PACK / path).read_text(), f'{path} is out of date')

    def test_every_prompt_is_a_whole_spec(self):
        jobs = self.jobs()
        self.assertEqual(len({j['id'] for j in jobs}), len(jobs))
        for job in jobs:
            lines = job['prompt'].splitlines()
            labels = [line.split(':', 1)[0] for line in lines]
            for label in LABELS:
                self.assertIn(label, labels, f"{job['id']} has no {label} line")
            for mark in ('{', '}', 'None', '  '):
                self.assertNotIn(mark, job['prompt'], f"{job['id']} has an unfilled or untidy prompt")
            self.assertIn('no text', job['prompt'])
            self.assertTrue(job['checks'])
            # An edit names its target as Image 1; a new image never says "edit target".
            self.assertEqual('Image 1: edit target' in job['prompt'], job['edit'], job['id'])

    def test_every_reference_a_job_names_comes_from_the_plan(self):
        plan = json.loads((PACK / 'data/plan.json').read_text())
        styles = json.loads((PACK / 'data/styles.json').read_text())['order']
        views = {f['view'] for f in plan['frames']}
        sheets = {s['id'] for s in plan['design_sheets']}
        for job in self.jobs():
            for path, _ in job['refs']:
                parts = Path(path).parts
                if parts[0] == 'sheets':
                    # A life-cycle job loads the newest image of its object's design sheet.
                    self.assertEqual(job['family'], 'E', path)
                    self.assertEqual((parts[1], parts[3], parts[4]), (job['style'], 'LATEST', 'image.png'), path)
                    self.assertIn(parts[2], sheets, path)
                    continue
                kind, style, name = parts[1:4]
                self.assertIn(style, styles, path)
                self.assertIn(Path(name).stem, plan['panels'] if kind == 'panels' else views, path)

    def test_a_night_style_is_asked_for_in_neutral_light_on_design_images(self):
        styles = json.loads((PACK / 'data/styles.json').read_text())['styles']
        night = {name for name, style in styles.items() if style.get('night_design')}
        self.assertEqual(night, {'neon_noir'})
        for job in self.jobs():
            asked = 'their light does not fall on the object' in job['prompt']
            self.assertEqual(asked, job['style'] in night and job['family'] in ('A', 'E') or (job['style'] in night and job['kind'] == 'cut-out atlas'), job['id'])
            if job['style'] in night and job['family'] == 'A':
                self.assertNotIn('warm highlights', job['prompt'], job['id'])       # a lit colour, not a surface's own
                self.assertIn('It is not a night scene', ' '.join(job['checks']), job['id'])

    def test_a_job_asked_for_again_is_not_done_until_it_has_a_second_image(self):
        plan = json.loads((PACK / 'data/plan.json').read_text())
        run('build_jobs.py', cwd=self.pack)
        again = next(iter(plan['redo']))
        job = next(j for j in self.jobs() if j['id'] == again)
        self.assertEqual(job['batch'], '00b-pilot-rest')
        image = Path(self.temp.name) / 'made.png'
        image.write_bytes(png(*job['size']))
        shutil.copytree(PACK / 'refs', self.pack / 'refs')
        self.assertEqual(run('intake.py', 'add', again, str(image), cwd=self.pack).returncode, 0)
        self.assertIn('to do again', run('intake.py', 'status', '00b-pilot-rest', cwd=self.pack).stdout)
        self.assertEqual(run('intake.py', 'add', again, str(image), cwd=self.pack).returncode, 0)
        status = run('intake.py', 'status', '00b-pilot-rest', cwd=self.pack).stdout
        self.assertNotIn('to do again', status)
        self.assertIn('r002', status)

    def test_a_correction_is_kept_with_the_jobs_prompt(self):
        run('build_jobs.py', cwd=self.pack)
        job = next(j for j in self.jobs() if not j['refs'])
        image = Path(self.temp.name) / 'made.png'
        image.write_bytes(png(*job['size']))
        added = run('intake.py', 'add', job['id'], str(image), '--correction', 'remove the label under the trunk', cwd=self.pack)
        self.assertEqual(added.returncode, 0, added.stderr)
        text = (self.pack / job['out'] / 'r001/prompt.txt').read_text()
        self.assertTrue(text.startswith(job['prompt']))
        self.assertIn('remove the label under the trunk', text)
        record = json.loads((self.pack / job['out'] / 'r001/generation.json').read_text())
        self.assertFalse(record['prompt']['is_the_jobs'])
        self.assertEqual(record['prompt']['correction'], 'remove the label under the trunk')
        self.assertEqual(run('intake.py', 'check', cwd=self.pack).returncode, 0)

    def test_a_life_cycle_record_names_the_design_sheet_revision_it_was_given(self):
        run('build_jobs.py', cwd=self.pack)
        shutil.copytree(PACK / 'refs', self.pack / 'refs')
        job = next(j for j in self.jobs() if j['family'] == 'E')
        sheet = next(path for path, _ in job['refs'] if path.startswith('sheets/'))
        design = next(j for j in self.jobs() if j['out'] == str(Path(sheet).parents[1]))
        image = Path(self.temp.name) / 'made.png'
        image.write_bytes(png(*design['size']))
        for _ in range(2):
            self.assertEqual(run('intake.py', 'add', design['id'], str(image), cwd=self.pack).returncode, 0)
        self.assertEqual(run('intake.py', 'add', job['id'], str(image), cwd=self.pack).returncode, 0)
        record = json.loads((self.pack / job['out'] / 'r001/generation.json').read_text())
        self.assertTrue(any(ref.endswith(f"{design['out']}/r002/image.png") for ref in record['reference_images']), record['reference_images'])
        self.assertEqual(run('intake.py', 'check', cwd=self.pack).returncode, 0)

    def test_filing_never_overwrites_and_check_sees_tampering(self):
        run('build_jobs.py', cwd=self.pack)
        job = next(j for j in self.jobs() if not j['refs'])           # a plain shape: no reference images to supply
        image = Path(self.temp.name) / 'made.png'
        image.write_bytes(png(*job['size']))
        for expected in ('r001', 'r002'):
            added = run('intake.py', 'add', job['id'], str(image), cwd=self.pack)
            self.assertEqual(added.returncode, 0, added.stderr)
            self.assertTrue((self.pack / job['out'] / expected / 'image.png').exists())
        record = json.loads((self.pack / job['out'] / 'r001/generation.json').read_text())
        self.assertEqual((record['width'], record['height']), tuple(job['size']))
        self.assertTrue(record['prompt']['is_the_jobs'])
        self.assertEqual(run('intake.py', 'check', cwd=self.pack).returncode, 0)
        with open(self.pack / job['out'] / 'r001/prompt.txt', 'a') as prompt:
            prompt.write('changed')
        checked = run('intake.py', 'check', cwd=self.pack)
        self.assertEqual(checked.returncode, 1)
        self.assertIn('does not match its recorded hash', checked.stdout)

    def test_a_review_that_names_a_local_path_is_a_fault(self):
        run('build_jobs.py', cwd=self.pack)
        job = next(j for j in self.jobs() if not j['refs'])
        image = Path(self.temp.name) / 'made.png'
        image.write_bytes(png(*job['size']))
        self.assertEqual(run('intake.py', 'add', job['id'], str(image), cwd=self.pack).returncode, 0)
        self.assertEqual(run('intake.py', 'check', cwd=self.pack).returncode, 0)
        with open(self.pack / job['out'] / 'r001/review.md', 'a') as review:
            review.write('- Original candidate: ' + '/ho' + 'me/someone/.codex/generated_images/a/exec-1.png\n')
        checked = run('intake.py', 'check', cwd=self.pack)
        self.assertEqual(checked.returncode, 1)
        self.assertIn('home directory', checked.stdout)

    def test_a_wrong_shape_is_filed_and_reported(self):
        run('build_jobs.py', cwd=self.pack)
        job = next(j for j in self.jobs() if not j['refs'] and j['size'] == [1024, 1024])
        image = Path(self.temp.name) / 'wide.png'
        image.write_bytes(png(1536, 1024))
        added = run('intake.py', 'add', job['id'], str(image), cwd=self.pack)
        self.assertEqual(added.returncode, 0, added.stderr)
        self.assertIn('NOTE', added.stdout)
        self.assertIn('Shape:', (self.pack / job['out'] / 'r001/review.md').read_text())
        self.assertEqual(run('intake.py', 'check', cwd=self.pack).returncode, 1)


if __name__ == '__main__':
    unittest.main()
