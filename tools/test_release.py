"""Release gate checks without contacting Apple or itch.io."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from deploy_itch import upload_commands
from notarize_macos import ROOT, digest, notarize


class NotarizationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='test-release-', dir=ROOT / 'build')
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        (self.folder / 'macos').mkdir()
        self.archive = self.folder / 'macos/Nugget Cat.zip'
        self.archive.write_bytes(b'test archive')
        self.receipt = {
            'submission_id': 'test-submission', 'notary_profile': 'test-profile',
            'status': 'Accepted', 'stapled': True,
            'archive_sha256': digest(self.archive),
        }
        self.config = {'project': 'test/game', 'channels': {'macos': 'mac'}}

    def save(self):
        (self.folder / 'macos/notarization.json').write_text(json.dumps(self.receipt))

    def commands(self):
        return upload_commands('butler', self.config, self.folder, ['macos'], '1.0.0')

    def test_upload_requires_acceptance_and_stapling(self):
        for status, stapled in [('Submitted', False), ('Invalid', False), ('Accepted', False)]:
            with self.subTest(status=status, stapled=stapled):
                self.receipt.update(status=status, stapled=stapled)
                self.save()
                with self.assertRaises(ValueError):
                    self.commands()

    def test_modified_archive_cannot_upload_or_resume(self):
        self.save()
        self.archive.write_bytes(b'changed after notarization')
        with self.assertRaises(ValueError):
            self.commands()
        with patch('notarize_macos.subprocess.run') as run:
            with self.assertRaises(ValueError):
                notarize(self.folder, resume=True)
            run.assert_not_called()

    def test_accepted_stapled_archive_can_upload(self):
        self.save()
        self.assertEqual(self.commands()[0][-3:], ['test/game:mac', '--userversion', '1.0.0'])

    def test_rejection_does_not_staple_or_repackage(self):
        self.receipt.update(status='Submitted', stapled=False)
        self.save()
        commands = []

        def fake_run(command, **kwargs):
            commands.append(command)
            kwargs['stdout'].write(json.dumps({'status': 'Invalid'}))
            return subprocess.CompletedProcess(command, 0)

        with patch('notarize_macos.subprocess.run', side_effect=fake_run):
            with self.assertRaisesRegex(RuntimeError, 'Apple returned Invalid'):
                notarize(self.folder, resume=True)
        self.assertEqual([command[2] for command in commands], ['wait', 'log'])
        saved = json.loads((self.folder / 'macos/notarization.json').read_text())
        self.assertFalse(saved['stapled'])
        self.assertEqual(saved['status'], 'Invalid')


if __name__ == '__main__':
    unittest.main()
