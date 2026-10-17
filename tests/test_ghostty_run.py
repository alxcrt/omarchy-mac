#!/opt/homebrew/bin/python3
"""Verify terminal input through an osascript recorder, without desktop access."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GhosttyRunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='omarchy ghostty-run ')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.log = self.base / 'osascript.json'
        self.env = dict(os.environ, PATH=f'{self.bin}:/usr/bin:/bin',
                        GHOSTTY_RUN_LOG=str(self.log))
        script = self.bin / 'osascript'
        script.write_text('''#!/opt/homebrew/bin/python3
import json, os, sys
from pathlib import Path
Path(os.environ['GHOSTTY_RUN_LOG']).write_text(json.dumps({
    'args': sys.argv[1:], 'script': sys.stdin.read()}))
print('recorder output must stay hidden')
raise SystemExit(int(os.environ.get('GHOSTTY_RUN_EXIT', 0)))
''')
        script.chmod(0o755)

    def launch(self, *args):
        result = subprocess.run(['/bin/bash', str(ROOT / 'local/bin/ghostty-run'), *args],
                                cwd=self.base, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.stdout, '')
        return result, json.loads(self.log.read_text())

    def test_empty_launch_preserves_working_directory(self):
        result, call = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(call['args'], ['-', str(self.base.resolve()), ''])
        self.assertIn('new window with configuration cfg', call['script'])
        self.assertNotIn('System Events', call['script'])

    def test_one_argument_retains_raw_shell_command_mode(self):
        command = "printf '%s' raw > marker"
        result, call = self.launch(command)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(call['args'][2], command + '\n')
        executed = subprocess.run(['/bin/zsh', '-f', '-c', call['args'][2]], cwd=self.base)
        self.assertEqual(executed.returncode, 0)
        self.assertEqual((self.base / 'marker').read_text(), 'raw')

    def test_multiple_arguments_survive_spaces_quotes_newlines_and_shell_syntax(self):
        emitter = self.base / 'capture arguments'
        emitter.write_text('#!/opt/homebrew/bin/python3\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n')
        emitter.chmod(0o755)
        args = ['', 'path with spaces', "single' and double\" quotes", 'line one\nline two',
                '; touch unwanted', '$(touch unwanted)', '`touch unwanted`',
                '*?[abc]', '--option=value', 'back\\slash', 'snowman ☃']
        result, call = self.launch(str(emitter), *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        executed = subprocess.run(['/bin/zsh', '-f', '-c', call['args'][2]],
                                  cwd=self.base, text=True, capture_output=True)
        self.assertEqual(executed.returncode, 0, executed.stderr)
        self.assertEqual(json.loads(executed.stdout), args)
        self.assertFalse((self.base / 'unwanted').exists())

    def test_osascript_failure_is_returned(self):
        self.env['GHOSTTY_RUN_EXIT'] = '37'
        result, _ = self.launch('printf', 'hello')
        self.assertEqual(result.returncode, 37)


if __name__ == '__main__':
    unittest.main(verbosity=2)
