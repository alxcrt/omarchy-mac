#!/opt/homebrew/bin/python3
"""Exercise launch dispatch and browser selection without desktop access."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RaycastTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='omarchy-raycast-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / 'home'
        self.bin = self.home / '.local/bin'
        self.bin.mkdir(parents=True)
        (self.home / 'Developer').mkdir()
        self.log = self.base / 'calls.jsonl'
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=f'{self.bin}:/usr/bin:/bin', RAYCAST_TEST_LOG=str(self.log))
        for key in ('OMARCHY_BROWSER', 'CMUX_SURFACE_ID'):
            self.env.pop(key, None)
        stub = '''#!/opt/homebrew/bin/python3
import json, os, sys
from pathlib import Path
with open(os.environ['RAYCAST_TEST_LOG'], 'a') as f:
    f.write(json.dumps([Path(sys.argv[0]).name, sys.argv[1:], os.getcwd()]) + '\\n')
print('stub output')
'''
        for name in ('ghostty-run', 'mac', 'weburl', 'transcode-pick'):
            self.write_executable(self.bin / name, stub)

    def write_executable(self, path, text):
        path.write_text(text)
        path.chmod(0o755)

    def run_helper(self, *args):
        return subprocess.run(['/bin/bash', str(ROOT / 'local/bin/mac-raycast'), *args],
                              env=self.env, text=True, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_dispatch_reuses_existing_commands(self):
        expected = {
            'update': ('ghostty-run', ['macup']),
            'health': ('ghostty-run', ['mac', 'doctor']),
            'usage': ('mac', ['usage']), 'keys': ('mac', ['keys']),
            'transcode': ('transcode-pick', []),
            'monitor': ('ghostty-run', ['btop']),
            'docker': ('ghostty-run', ['lazydocker']),
            'editor': ('ghostty-run', ['nvim']),
            'copy-url': ('weburl', []), 'download': ('ghostty-run', ['webdl']),
            **{h: ('ghostty-run', ['cmux-fleet', h])
               for h in ('houston', 'nasa', 'coolify', 'titan')},
        }
        for action, (command, argv) in expected.items():
            with self.subTest(action=action):
                result = self.run_helper('run', action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[-1], [command, argv, str((self.home / 'Developer').resolve())])

    def test_dispatch_rejects_unknown_and_shell_input(self):
        for args in [('run',), ('run', 'bogus'), ('run', 'download', '; touch unwanted'),
                     ('run', 'houston; touch unwanted')]:
            with self.subTest(args=args):
                self.assertEqual(self.run_helper(*args).returncode, 2)
        self.assertFalse(self.log.exists())

    def test_wrappers_pass_fixed_actions_and_do_not_start_background_jobs(self):
        # Replace only the dispatch executable in the isolated home. Even the
        # app-opening wrappers are now observed without contacting the desktop.
        self.write_executable(self.bin / 'mac-raycast',
                              (self.bin / 'ghostty-run').read_text())
        scripts = sorted((ROOT / 'config/raycast/scripts').glob('*.sh'))
        self.assertEqual(len(scripts), 16)
        for script in scripts:
            with self.subTest(script=script.name):
                result = subprocess.run(['/bin/bash', str(script)], env=self.env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                action = script.stem.removeprefix('omarchy-')
                self.assertEqual(self.calls()[-1][1], ['run', action])
                self.assertNotIn('@raycast.refreshTime', script.read_text())

    def test_prepare_merges_private_links_without_publishing_them(self):
        private = self.home / '.config/raycast/omarchy-quicklinks.local.json'
        private.parent.mkdir(parents=True)
        defaults = json.loads((ROOT / 'config/raycast/quicklinks.json').read_text())
        private.write_text(json.dumps([defaults[0], {'name': 'Private test', 'link': 'https://test.invalid/'}]))
        out = self.home / '.local/share/omarchy-mac/raycast/quicklinks.json'
        result = self.run_helper('prepare')
        self.assertEqual(result.returncode, 0, result.stderr)
        links = json.loads(out.read_text())
        self.assertEqual(len(links), len(defaults) + 1)
        self.assertEqual(links[-1]['name'], 'Private test')
        self.assertEqual(out.stat().st_mode & 0o777, 0o600)
        self.assertEqual(out.parent.stat().st_mode & 0o777, 0o700)
        before = out.read_bytes()
        self.assertEqual(self.run_helper('prepare').returncode, 0)
        self.assertEqual(out.read_bytes(), before)
        private.write_text('[{"name": "Invalid link"}]')
        self.assertNotEqual(self.run_helper('prepare').returncode, 0)
        self.assertEqual(out.read_bytes(), before)

    def test_snippets_are_importable_without_accidental_command_execution(self):
        snippets = json.loads((ROOT / 'config/raycast/snippets.json').read_text())
        self.assertEqual(len({s['keyword'] for s in snippets}), len(snippets))
        for snippet in snippets:
            self.assertTrue(snippet['name'])
            self.assertTrue(snippet['keyword'].startswith(';;'))
            self.assertNotIn('\n', snippet['text'])
            self.assertNotIn('\r', snippet['text'])

    def test_status_distinguishes_files_from_app_configuration(self):
        result = self.run_helper('status')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('0/16', result.stdout)
        self.assertIn('Metadata cannot confirm', result.stdout)

    def browser_fixture(self, default, state):
        apps = self.base / 'Applications'
        apps.mkdir()
        for app in state:
            (apps / f'{app}.app').mkdir()
        self.env['OMARCHY_BROWSER_APPLICATIONS_DIR'] = str(apps)
        self.env['RAYCAST_TEST_BROWSERS'] = json.dumps(state)
        if default:
            p = self.home / 'Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist'
            p.parent.mkdir(parents=True)
            p.write_bytes(plistlib.dumps({'LSHandlers': [
                {'LSHandlerURLScheme': 'https', 'LSHandlerRoleAll': default}]}))
        self.write_executable(self.bin / 'osascript', '''#!/opt/homebrew/bin/python3
import json, os, re, sys
script = sys.argv[2]
match = re.search(r'application ("(?:[^"\\\\]|\\\\.)*")', script)
if not match:
    raise SystemExit(2)
app = json.loads(match.group(1))
state = json.loads(os.environ['RAYCAST_TEST_BROWSERS'])
with open(os.environ['RAYCAST_TEST_LOG'], 'a') as f:
    f.write(json.dumps([app, script]) + '\\n')
if 'is running' in script:
    print('true' if state.get(app, {}).get('running') else 'false')
else:
    url = state.get(app, {}).get('url')
    if not url:
        raise SystemExit(1)
    print(url)
''')

    def run_browser(self):
        return subprocess.run(['/bin/bash', str(ROOT / 'local/bin/browser-url')],
                              env=self.env, text=True, capture_output=True)

    def test_browser_prefers_default_helium_over_running_chrome(self):
        self.browser_fixture('net.imput.helium', {
            'Helium': {'running': True, 'url': 'https://helium.invalid/'},
            'Google Chrome': {'running': True, 'url': 'https://chrome.invalid/'}})
        result = self.run_browser()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'https://helium.invalid/')
        self.assertEqual(self.calls()[0][0], 'Helium')

    def test_browser_respects_default_chrome_on_another_mac(self):
        self.browser_fixture('com.google.Chrome', {
            'Helium': {'running': True, 'url': 'https://helium.invalid/'},
            'Google Chrome': {'running': True, 'url': 'https://chrome.invalid/'}})
        self.assertEqual(self.run_browser().stdout, 'https://chrome.invalid/')

    def test_browser_falls_back_without_launching_closed_default(self):
        self.browser_fixture('net.imput.helium', {
            'Helium': {'running': False},
            'Google Chrome': {'running': True, 'url': 'https://chrome.invalid/'}})
        self.assertEqual(self.run_browser().stdout, 'https://chrome.invalid/')
        self.assertFalse(any('tell application "Helium"' in c[1] for c in self.calls()))

    def test_browser_honors_explicit_override(self):
        self.browser_fixture('net.imput.helium', {
            'Helium': {'running': True, 'url': 'https://helium.invalid/'},
            'Google Chrome': {'running': True, 'url': 'https://chrome.invalid/'}})
        self.env['OMARCHY_BROWSER'] = 'Google Chrome'
        self.assertEqual(self.run_browser().stdout, 'https://chrome.invalid/')
        self.assertTrue(all(c[0] == 'Google Chrome' for c in self.calls()))

    def test_browser_reports_no_open_tab(self):
        self.browser_fixture('net.imput.helium', {'Helium': {'running': True}})
        result = self.run_browser()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, '')
        self.assertIn('No Chromium-family browser', result.stderr)

    def test_browser_works_without_launch_services_settings(self):
        self.browser_fixture(None, {'Helium': {'running': True, 'url': 'https://helium.invalid/'}})
        self.assertEqual(self.run_browser().stdout, 'https://helium.invalid/')

    def test_browser_treats_quoted_application_name_as_data(self):
        name = 'Browser "Quoted"'
        self.browser_fixture(None, {name: {'running': True, 'url': 'https://quoted.invalid/'}})
        self.env['OMARCHY_BROWSER'] = name
        self.assertEqual(self.run_browser().stdout, 'https://quoted.invalid/')


if __name__ == '__main__':
    unittest.main(verbosity=2)
