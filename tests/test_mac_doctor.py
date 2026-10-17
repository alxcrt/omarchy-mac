"""Check that doctor preserves failures and finishes every health check."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DoctorTests(unittest.TestCase):
    def run_doctor(self, failed=None):
        with tempfile.TemporaryDirectory(prefix='mac-doctor-test-') as directory:
            bindir = Path(directory)
            checks = ('mise', 'brew', 'mac-wm', 'mac-keyremap', 'mac-defaults')
            for name in checks:
                output = '30064771298' if name == 'mac-keyremap' else f'{name} complete'
                if name == failed:
                    output = '\n'.join(f'{name} warning {i}' for i in range(8))
                script = bindir / name
                script.write_text('#!/bin/sh\ncat <<\'EOF\'\n' + output +
                                  '\nEOF\nexit ' + ('1' if name == failed else '0') + '\n')
                script.chmod(0o755)
            return subprocess.run(
                ['/bin/bash', str(ROOT / 'local/bin/mac'), 'doctor'],
                env={**os.environ, 'PATH': f'{bindir}:/usr/bin:/bin'},
                text=True, capture_output=True,
            )

    def test_success(self):
        result = self.run_doctor()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('modifier remap loaded', result.stdout)
        self.assertIn('mac-defaults complete', result.stdout)

    def test_failure_keeps_full_diagnostics_and_continues(self):
        for name in ('mise', 'brew', 'mac-wm', 'mac-defaults'):
            with self.subTest(check=name):
                result = self.run_doctor(name)
                self.assertNotEqual(result.returncode, 0)
                for index in range(8):
                    self.assertIn(f'{name} warning {index}', result.stdout)
                self.assertIn('== macOS defaults ==', result.stdout)

    def test_missing_mapping_fails_and_still_checks_defaults(self):
        result = self.run_doctor('mac-keyremap')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('modifier remap MISSING', result.stdout)
        self.assertIn('mac-defaults complete', result.stdout)


if __name__ == '__main__':
    unittest.main()
