#!/opt/homebrew/bin/python3
"""Verify generated shortcut information without keystrokes or app launches."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MacKeysTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='omarchy-keys-')
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        (self.home / '.config').mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        PATH=f'{self.bin}:/usr/bin:/bin')
        self.executable('hidutil', '#!/bin/bash\necho "(null)"\n')
        self.executable('mac-wm', '#!/bin/bash\necho "Spaces|ctrl+1|Desktop 1"\n')
        self.rex_keymap({'bindings': [], 'modes': [], 'diagnostics': []})

    def executable(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o755)
        return path

    def rex_keymap(self, keymap, exit_code=0):
        """A stub `rex` that answers `rex keymap --json` like the server does."""
        body = json.dumps(keymap) if isinstance(keymap, dict) else keymap
        self.env['REX_BIN'] = str(self.executable('rex', f'''#!/opt/homebrew/bin/python3
import sys
assert sys.argv[1:] == ['keymap', '--json'], sys.argv
print({body!r})
raise SystemExit({exit_code})
'''))

    def run_keys(self, *args):
        return subprocess.run(['/bin/bash', str(ROOT / 'local/bin/mac-keys'), *args],
                              env=self.env, text=True, capture_output=True)

    def test_raycast_guide_is_distinguished_from_live_registration(self):
        absent = self.run_keys('--md')
        self.assertNotIn('Raycast (setup guide;', absent.stdout)
        guide = self.home / '.config/raycast/omarchy-hotkeys.tsv'
        guide.parent.mkdir()
        guide.write_text('# comment\nHyper+V\tClipboard | History\n')
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Raycast (setup guide; verify in Settings > Shortcuts)', result.stdout)
        self.assertIn('assignments are app-owned, not read live', result.stdout)
        self.assertIn('| `Hyper+V` | Clipboard \\| History |', result.stdout)
        self.assertNotIn('# comment', result.stdout)

    def test_rex_bindings_group_sequences_modes_and_args(self):
        self.rex_keymap({'bindings': [
            {'keys': ['alt+enter'], 'action': 'pane.split', 'args': {'direction': 'down'}},
            {'keys': ['ctrl+space', 'h'], 'action': 'pane.split', 'args': {'direction': 'down'}},
            {'keys': ['left'], 'action': 'pane.resize', 'args': {'direction': 'left'}, 'mode': 'resize'},
            {'keys': ['alt+[Digit1]'], 'action': 'client.tab.goto', 'args': {'index': 1}},
            {'keys': ['ctrl+p'], 'action': 'pane.send_key', 'args': {'key': 'a|b', 'repeat': 2}},
        ], 'modes': [{'name': 'resize', 'exclusive': True}], 'diagnostics': []})
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        # One row per action, chords before sequences, mode keys marked.
        self.assertIn('| `alt+enter / ctrl+space → h` | pane.split down |', result.stdout)
        self.assertIn('| `resize/left` | pane.resize left |', result.stdout)
        self.assertIn('| `alt+[Digit1]` | client.tab.goto 1 |', result.stdout)
        self.assertIn('pane.send_key a\\|b repeat=2', result.stdout)
        self.assertIn("Rex's built-in defaults", result.stdout)
        self.assertNotIn('herdr', result.stdout)
        self.assertNotIn('Ghostty', result.stdout)

    def test_rex_diagnostics_reach_stderr(self):
        self.rex_keymap({'bindings': [], 'diagnostics': [{'severity': 'error', 'message': 'bad key'}]})
        result = self.run_keys()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('bad key', result.stderr)

    def test_rex_failure_is_not_reported_as_an_empty_success(self):
        self.rex_keymap('', exit_code=1)
        result = self.run_keys()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot read the Rex keymap', result.stderr)
        self.env['REX_BIN'] = str(self.bin / 'missing')
        result = self.run_keys()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot read the Rex keymap', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
