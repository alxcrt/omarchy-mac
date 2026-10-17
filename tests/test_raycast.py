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
        for name in ('ghostty-run', 'mac', 'weburl', 'transcode-pick', 'open'):
            self.write_executable(self.bin / name, stub)
        self.env['MAC_RAYCAST_OPEN_BIN'] = str(self.bin / 'open')

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
            'mise': ('ghostty-run', ['mac', 'mise']),
            'health': ('ghostty-run', ['mac', 'doctor']),
            'usage': ('mac', ['usage']), 'keys': ('mac', ['keys']),
            'transcode': ('transcode-pick', []),
            'monitor': ('ghostty-run', ['btop']),
            'dev-doctor': ('ghostty-run', ['mac', 'dev', 'doctor']),
            'git': ('ghostty-run', ['mac', 'dev', 'git', 'ui']),
            'docker': ('ghostty-run', ['mac', 'dev', 'docker', 'ui']),
            'api': ('mac', ['dev', 'api', 'open']),
            'database': ('mac', ['dev', 'db', 'open']),
            'editor': ('ghostty-run', ['nvim']),
            'music': ('ghostty-run', ['cliamp']),
            'music-setup': ('ghostty-run', ['cliamp', 'setup']),
            'terminal': ('open', ['-a', 'cmux']),
            'ghostty': ('open', ['-a', 'Ghostty']),
            'archive': ('open', ['-a', 'Keka']),
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

    def test_optional_wrappers_pass_fixed_actions(self):
        # Replace only the dispatch executable in the isolated home. Even the
        # app-opening wrappers are now observed without contacting the desktop.
        self.write_executable(self.bin / 'mac-raycast',
                              (self.bin / 'ghostty-run').read_text())
        scripts = sorted((ROOT / 'config/raycast/optional').glob('*.sh'))
        self.assertEqual(len(scripts), 23)
        for script in scripts:
            with self.subTest(script=script.name):
                self.assertTrue(os.access(script, os.X_OK))
                result = subprocess.run(['/bin/bash', str(script)], env=self.env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                action = script.stem.removeprefix('omarchy-')
                self.assertEqual(self.calls()[-1][1], ['run', action])
                self.assertNotIn('@raycast.refreshTime', script.read_text())

    def test_single_menu_has_valid_choices_and_forwards_them_as_data(self):
        scripts = list((ROOT / 'config/raycast/scripts').glob('*.sh'))
        self.assertEqual(len(scripts), 1)
        script = scripts[0]
        metadata = next(line.split('@raycast.argument1 ', 1)[1]
                        for line in script.read_text().splitlines()
                        if '@raycast.argument1 ' in line)
        argument = json.loads(metadata)
        self.assertEqual(argument['type'], 'dropdown')
        choices = argument['data']
        # A default/first selection must open reference information, not an update.
        self.assertEqual(choices[0]['value'], 'keys')
        self.assertEqual(len({c['value'] for c in choices}), len(choices))
        self.assertNotIn('terminal', {c['value'] for c in choices})
        self.assertNotIn('ghostty', {c['value'] for c in choices})
        # GUI apps stay in Raycast's normal app search. CLIamp and the dev
        # workflows need a terminal, so they belong in the one Omarchy menu.
        values = {c['value'] for c in choices}
        self.assertTrue({'dev-doctor', 'git', 'docker', 'music'} <= values)
        self.assertTrue({'api', 'database', 'archive'}.isdisjoint(values))
        for choice in choices:
            with self.subTest(dispatch=choice['value']):
                result = self.run_helper('menu', choice['value'])
                self.assertEqual(result.returncode, 0, result.stderr)
        self.write_executable(self.bin / 'mac-raycast', (self.bin / 'ghostty-run').read_text())
        for choice in choices:
            with self.subTest(choice=choice['title']):
                result = subprocess.run(['/bin/bash', str(script), choice['value']],
                                        env=self.env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[-1][1], ['menu', choice['value']])
        self.assertNotIn('@raycast.refreshTime', script.read_text())

    def test_menu_keeps_information_visible_and_rejects_extra_input(self):
        for action in ('usage', 'keys'):
            result = self.run_helper('menu', action)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.calls()[-1][:2], ['ghostty-run', ['mac', action]])
        result = self.run_helper('menu', 'update')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][:2], ['ghostty-run', ['macup']])
        count = len(self.calls())
        for args in [('menu',), ('menu', 'usage', 'extra'), ('menu', '; touch unwanted')]:
            self.assertEqual(self.run_helper(*args).returncode, 2)
        self.assertEqual(len(self.calls()), count)

    def test_installer_migrates_only_owned_links_and_is_idempotent(self):
        scripts = self.home / '.config/raycast/scripts'
        scripts.mkdir(parents=True)
        old = scripts / 'omarchy-update.sh'
        old.symlink_to(ROOT / 'config/raycast/scripts/omarchy-update.sh')
        custom = scripts / 'omarchy-health.sh'
        custom.write_text('user-owned script\n')
        other = scripts / 'omarchy-keys.sh'
        other.symlink_to(self.bin / 'mac')
        for _ in range(2):
            result = subprocess.run(['/bin/bash', str(ROOT / 'install.sh'), '--links'],
                                    env=self.env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(old.is_symlink())
            self.assertEqual(custom.read_text(), 'user-owned script\n')
            self.assertEqual(other.resolve(), (self.bin / 'mac').resolve())
            self.assertEqual((scripts / 'omarchy.sh').resolve(),
                             (ROOT / 'config/raycast/scripts/omarchy.sh').resolve())

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
        self.assertIn('0/1', result.stdout)
        self.assertIn('Metadata cannot confirm', result.stdout)
        self.assertIn('Bruno (API), DBeaver (databases), Keka (archives)', result.stdout)

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
