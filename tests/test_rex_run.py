#!/opt/homebrew/bin/python3
"""Verify rex-run through osascript and rex recorders, without desktop access."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RexRunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='omarchy rex-run ')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.log = self.base / 'calls.jsonl'
        self.env = dict(os.environ, PATH=f'{self.bin}:/usr/bin:/bin:/opt/homebrew/bin',
                        REX_RUN_LOG=str(self.log), REX_SESSIONS='')
        # osascript records its arguments and the script; rex answers `ls`,
        # `new --json` and `send` like the server, from REX_SESSIONS.
        self.executable('osascript', '''#!/opt/homebrew/bin/python3
import json, os, sys
with open(os.environ['REX_RUN_LOG'], 'a') as f:
    f.write(json.dumps(['osascript', sys.argv[1:], sys.stdin.read()]) + '\\n')
print('recorder output must stay hidden')
raise SystemExit(int(os.environ.get('REX_RUN_EXIT', 0)))
''')
        self.executable('rex', '''#!/opt/homebrew/bin/python3
import json, os, sys
with open(os.environ['REX_RUN_LOG'], 'a') as f:
    f.write(json.dumps(['rex', sys.argv[1:], os.getcwd()]) + '\\n')
if sys.argv[1] == 'ls':
    print('LABEL  ID')
    for name in filter(None, os.environ['REX_SESSIONS'].split(',')):
        print(f'{name}  abc123')
elif sys.argv[1] == 'new':
    print(json.dumps({'session_id': 'session:new',
                      'initial_windows': [{'window_id': 'window:w', 'block_ids': ['block:b1']}]}))
''')

    def executable(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o755)

    def launch(self, *args):
        result = subprocess.run(['/bin/bash', str(ROOT / 'local/bin/rex-run'), *args],
                                cwd=self.base, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.stdout, '')
        calls = [json.loads(l) for l in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def osascript(self, calls):
        return [c for c in calls if c[0] == 'osascript']

    def test_empty_launch_opens_the_working_directory(self):
        result, calls = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        (_, args, script), = self.osascript(calls)
        self.assertEqual(args, ['-', 'open', '', str(self.base.resolve())])
        self.assertIn('com.superlogical.rex', script)
        self.assertNotIn('System Events', script)

    def test_one_argument_retains_raw_shell_command_mode(self):
        command = "printf '%s' raw > marker"
        result, calls = self.launch(command)
        self.assertEqual(result.returncode, 0, result.stderr)
        (_, args, script), = self.osascript(calls)
        self.assertEqual(args, ['-', 'run', command, str(self.base.resolve())])
        self.assertIn('run command arg1 at arg2', script)
        executed = subprocess.run(['/bin/zsh', '-f', '-c', args[2]], cwd=self.base)
        self.assertEqual(executed.returncode, 0)
        self.assertEqual((self.base / 'marker').read_text(), 'raw')

    def test_multiple_arguments_survive_spaces_quotes_newlines_and_shell_syntax(self):
        emitter = self.base / 'capture arguments'
        emitter.write_text('#!/opt/homebrew/bin/python3\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n')
        emitter.chmod(0o755)
        args = ['', 'path with spaces', "single' and double\" quotes", 'line one\nline two',
                '; touch unwanted', '$(touch unwanted)', '`touch unwanted`',
                '*?[abc]', '--option=value', 'back\\slash', 'snowman ☃']
        result, calls = self.launch(str(emitter), *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        (_, osa_args, _), = self.osascript(calls)
        executed = subprocess.run(['/bin/zsh', '-f', '-c', osa_args[2]],
                                  cwd=self.base, text=True, capture_output=True)
        self.assertEqual(executed.returncode, 0, executed.stderr)
        self.assertEqual(json.loads(executed.stdout), args)
        self.assertFalse((self.base / 'unwanted').exists())

    def test_named_session_is_created_once_then_only_shown(self):
        result, calls = self.launch('-s', 'houston', 'fleet', 'houston')
        self.assertEqual(result.returncode, 0, result.stderr)
        rex = [c[1] for c in calls if c[0] == 'rex']
        self.assertEqual(rex[1], ['new', 'houston', '-c', str(self.base.resolve()), '--json'])
        self.assertEqual(rex[2], ['send', '-b', 'block:b1', 'fleet houston\n'])
        self.assertEqual(self.osascript(calls)[-1][1], ['-', 'show', 'houston', ''])
        # A second launch finds the session and must not run the command again.
        self.log.unlink()
        self.env['REX_SESSIONS'] = 'humming-steppe,houston'
        result, calls = self.launch('-s', 'houston', 'fleet', 'houston')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[1][0] for c in calls if c[0] == 'rex'], ['ls'])
        self.assertEqual(self.osascript(calls)[-1][1], ['-', 'show', 'houston', ''])

    def test_session_name_must_not_match_a_prefix(self):
        self.env['REX_SESSIONS'] = 'houston-old'
        _, calls = self.launch('-s', 'houston', 'fleet', 'houston')
        self.assertIn('new', [c[1][0] for c in calls if c[0] == 'rex'])

    def test_usage_and_osascript_failure_are_returned(self):
        result, _ = self.launch('-s')
        self.assertEqual(result.returncode, 2)
        self.env['REX_RUN_EXIT'] = '37'
        result, _ = self.launch('printf', 'hello')
        self.assertEqual(result.returncode, 37)


if __name__ == '__main__':
    unittest.main(verbosity=2)
