"""Check the supported Linux/Mac routes without opening apps or updating tools."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get('OMARCHY_TEST_BASH', '/bin/bash')


class OmarchyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='omarchy-routes-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.log = self.base / 'calls.jsonl'
        stub = self.base / 'mac'
        stub.write_text('''#!/opt/homebrew/bin/python3
import json, os, sys
with open(os.environ['OMARCHY_TEST_LOG'], 'a') as f:
    f.write(json.dumps([sys.argv[1:], os.getcwd()]) + '\\n')
print('mac recorder output')
print('mac recorder diagnostic', file=sys.stderr)
raise SystemExit(int(os.environ.get('OMARCHY_TEST_STATUS', '0')))
''')
        stub.chmod(0o755)
        self.env = dict(os.environ, PATH=f'{self.base}:/usr/bin:/bin',
                        HOME=str(self.base), OMARCHY_TEST_LOG=str(self.log))

    def run_omarchy(self, *args, **env):
        return subprocess.run([BASH, str(ROOT / 'local/bin/omarchy'), *args],
                              cwd=self.base, env=dict(self.env, **env),
                              text=True, capture_output=True)

    def calls(self):
        return ([json.loads(line) for line in self.log.read_text().splitlines()]
                if self.log.exists() else [])

    def test_help_never_reaches_any_helper(self):
        cases = [(), ('help',), ('--help',), ('-h',), ('update', '--help'),
                 ('up', '-y', '-h'), ('update', 'aur', '--help'),
                 ('mise', 'install', 'package', '--help'),
                 ('launch', 'terminal', '--help'), ('raycast', 'setup', '-h'),
                 ('transcode', 'file', 'mp4', '1080p', '--help'), ('unknown', '-h')]
        for args in cases:
            with self.subTest(args=args):
                result = self.run_omarchy(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('shared everyday commands on macOS', result.stdout)
        self.assertEqual(self.calls(), [])

    def test_shared_routes_map_to_existing_mac_flows(self):
        routes = {
            ('update',): ['update'], ('up', '-y'): ['update', '-y'],
            ('mise', 'install', 'npm:example', 'example-cli', 'example-bin'):
                ['install', 'npm:example', 'example-cli', 'example-bin'],
            ('launch', 'terminal'): ['term'],
            ('launch', 'terminal', 'git', 'status'): ['term', 'git', 'status'],
            ('menu', 'keybindings'): ['keys'],
            ('menu', 'keybindings', '--print'): ['keys'],
            ('menu', 'keybindings', '-p'): ['keys'],
            ('transcode',): ['transcode'],
            ('transcode', 'video file.mov', 'mp4', '1080p'):
                ['transcode', 'video file.mov', 'mp4', '1080p'],
            ('transcode', 'photo.heic', 'jpg', 'medium'):
                ['transcode', 'photo.heic', 'jpg', 'medium'],
            ('keys', '--md'): ['keys', '--md'],
            ('dev', 'git', 'ui', 'project directory'): ['dev', 'git', 'ui', 'project directory'],
            ('doctor',): ['doctor'], ('raycast', 'status'): ['raycast', 'status'],
            ('usage', 'claude'): ['usage', 'claude'],
        }
        for args, expected in routes.items():
            with self.subTest(args=args):
                result = self.run_omarchy(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[-1], [expected, str(self.base.resolve())])

    def test_arguments_remain_data_and_child_help_uses_explicit_boundary(self):
        args = ['printf', 'spaces and "quotes"', '; touch unwanted', '$HOME', '\nnext line']
        result = self.run_omarchy('launch', 'terminal', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][0], ['term', *args])
        result = self.run_omarchy('launch', 'terminal', '--', 'python', '--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][0], ['term', 'python', '--help'])
        self.assertFalse((self.base / 'unwanted').exists())

    def test_unknown_linux_routes_and_unsupported_flags_do_not_dispatch(self):
        cases = [('theme',), ('update', 'aur'), ('update', '--invalid'),
                 ('update', '--', '--help'), ('mise',), ('mise', 'up'),
                 ('mise', 'install'), ('mise', 'install', '--', '-h'),
                 ('launch', 'editor', '.'), ('launch', 'terminal', '--pid=123'),
                 ('menu', 'keybindings', '--md'), ('menu', 'system'),
                 ('transcode', '--path', '/tmp'), ('transcode', 'ascii', 'file', 'out'),
                 ('transcode', 'file', 'mp4'), ('transcode', 'file', 'mp4', 'share')]
        for args in cases:
            with self.subTest(args=args):
                result = self.run_omarchy(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn('Unsupported Omarchy route on macOS', result.stderr)
                self.assertIn('omarchy help', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_child_status_stdout_and_stderr_are_preserved(self):
        result = self.run_omarchy('dev', 'status', OMARCHY_TEST_STATUS='17')
        self.assertEqual(result.returncode, 17)
        self.assertEqual(result.stdout, 'mac recorder output\n')
        self.assertEqual(result.stderr, 'mac recorder diagnostic\n')


if __name__ == '__main__':
    unittest.main()
