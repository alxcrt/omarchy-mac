#!/opt/homebrew/bin/python3
"""Verify generated shortcut information without keystrokes or app launches."""
import os
from pathlib import Path
import shutil
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
        self.config = self.home / '.config/ghostty'
        self.config.mkdir(parents=True)
        herdr = self.home / '.config/herdr/config.toml'
        herdr.parent.mkdir()
        herdr.write_text('[keys]\nprefix = "ctrl+space"\n')
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        PATH=f'{self.bin}:/usr/bin:/bin')
        self.executable('hidutil', '#!/bin/bash\necho "(null)"\n')
        self.executable('mac-wm', '#!/bin/bash\necho "Spaces|ctrl+1|Desktop 1"\n')
        self.executable('herdr', '#!/bin/bash\nprintf \'[keys]\\n# prefix = "ctrl+space"\\n# help = "prefix+?"\\n\'\n')

    def executable(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o755)
        return path

    def ghostty_output(self, text, exit_code=0):
        self.env['GHOSTTY_BIN'] = str(self.executable('ghostty', f'''#!/opt/homebrew/bin/python3
import sys
assert sys.argv[1:] == ['+list-keybinds', '--plain'], sys.argv
print({text!r})
print('fixture diagnostic', file=sys.stderr)
raise SystemExit({exit_code})
'''))

    def run_keys(self, *args):
        return subprocess.run(['/bin/bash', str(ROOT / 'local/bin/mac-keys'), *args],
                              env=self.env, text=True, capture_output=True)

    def test_effective_defaults_symbols_equals_plus_and_global_scope(self):
        self.config.joinpath('config').write_text(
            'keybind = global:command+grave_accent=toggle_quick_terminal\n')
        self.ghostty_output('''keybind = super+n=new_window
keybind = super+==increase_font_size:1
keybind = super++=increase_font_size:1
keybind = alt+arrow_left=esc:b
keybind = ctrl+shift+r=reload_config
keybind = super+backquote=toggle_quick_terminal
keybind = ctrl+p=text:a|b''')
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('| `⌘n` | new_window |', result.stdout)
        self.assertIn('| `⌘=` | increase_font_size:1 |', result.stdout)
        self.assertIn('| `⌘+` | increase_font_size:1 |', result.stdout)
        self.assertIn('| `⌥←` | esc:b |', result.stdout)
        self.assertIn('| `⌃⇧r` | reload_config |', result.stdout)
        self.assertIn('⌘Grave` | toggle_quick_terminal [global; requires Ghostty Accessibility]', result.stdout)
        self.assertIn('text:a\\|b', result.stdout)
        self.assertIn('Ghostty `super`/`cmd` = ⌘', result.stdout)
        self.assertNotIn('fixture diagnostic', result.stderr)

    def test_scope_includes_run_after_parent_and_native_config_wins(self):
        self.config.joinpath('config').write_text('''config-file = "extra"
keybind = global:opt+control+a=reload_config
keybind = global:cmd+b=reload_config
''')
        self.config.joinpath('extra').write_text('''keybind = all:control+option+a=reload_config
config-file = ?missing
config-file = config
''')
        native = self.home / 'Library/Application Support/com.mitchellh.ghostty'
        native.mkdir(parents=True)
        native.joinpath('config').write_text('keybind = cmd+b=reload_config\n')
        self.ghostty_output('keybind = ctrl+alt+a=reload_config\nkeybind = super+b=reload_config')
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('⌃⌥a` | reload_config [all terminal surfaces]', result.stdout)
        self.assertIn('| `⌘b` | reload_config |', result.stdout)
        self.assertNotIn('[global;', result.stdout)

    def test_clear_resets_prior_scope_without_resurrecting_unbound_keys(self):
        self.config.joinpath('config').write_text('''keybind = global:cmd+a=new_window
keybind = clear
keybind = cmd+a=reload_config
keybind = global:cmd+b=unbind
keybind = performable:unconsumed:ctrl+c=copy_to_clipboard
''')
        self.ghostty_output('keybind = super+a=reload_config\nkeybind = ctrl+c=copy_to_clipboard:mixed')
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('| `⌘a` | reload_config |', result.stdout)
        self.assertIn('[performable; unconsumed]', result.stdout)
        self.assertNotIn('⌘b', result.stdout)
        self.assertNotIn('[global;', result.stdout)

    def test_ghostty_failure_is_not_reported_as_an_empty_success(self):
        self.ghostty_output('', exit_code=37)
        result = self.run_keys()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot read effective Ghostty bindings', result.stderr)
        self.env['GHOSTTY_BIN'] = str(self.bin / 'missing')
        result = self.run_keys()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot read effective Ghostty bindings', result.stderr)

    def test_real_ghostty_merges_defaults_overrides_and_unbinds(self):
        ghostty = shutil.which('ghostty', path=os.environ['PATH'])
        if not ghostty:
            self.skipTest('Ghostty CLI unavailable')
        self.env['GHOSTTY_BIN'] = ghostty
        self.config.joinpath('config').write_text('''keybind = cmd+n=unbind
keybind = global:cmd+grave_accent=toggle_quick_terminal
keybind = ctrl+shift+r=reload_config
''')
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('| `⌘t` | new_tab |', result.stdout)
        self.assertIn('| `⌃⇧r` | reload_config |', result.stdout)
        self.assertIn('toggle_quick_terminal [global;', result.stdout)
        self.assertNotIn('| `⌘n` | new_window |', result.stdout)

    def test_repo_config_releases_option_arrows_for_herdr(self):
        ghostty = shutil.which('ghostty', path=os.environ['PATH'])
        if not ghostty:
            self.skipTest('Ghostty CLI unavailable')
        self.env['GHOSTTY_BIN'] = ghostty
        self.config.joinpath('config').write_bytes((ROOT / 'config/ghostty/config').read_bytes())
        result = self.run_keys('--md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('| `⌥←` | esc:b |', result.stdout)
        self.assertNotIn('| `⌥→` | esc:f |', result.stdout)
        self.assertIn('| `⌥⇧Enter` | csi:13;4u |', result.stdout)
        self.assertIn('| `⌘d` | new_split:right |', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
