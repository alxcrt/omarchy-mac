"""Exercise developer diagnostics and routing without services or desktop access."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
REAL_GIT = shutil.which('git')
PYTHON = '/opt/homebrew/bin/python3'
BASH = os.environ.get('MAC_DEV_TEST_BASH', '/bin/bash')


class DeveloperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='mac-dev-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / 'home'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.home.mkdir()
        self.apps = self.base / 'Applications'
        self.log = self.base / 'calls.jsonl'
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin',
                        MAC_DEV_APPLICATIONS_DIR=str(self.apps), DEV_TEST_LOG=str(self.log),
                        DEV_TEST_GIT=REAL_GIT)
        for name in ('Docker', 'Bruno', 'DBeaver'):
            plist = self.apps / f'{name}.app/Contents/Info.plist'
            plist.parent.mkdir(parents=True)
            plist.write_text('fixture app')
        stub = f'''#!{PYTHON}
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ['DEV_TEST_LOG'], 'a') as f:
    f.write(json.dumps([name, sys.argv[1:], os.getcwd(), os.environ.get('MISE_AUTO_INSTALL')]) + '\\n')
if name == 'git' and '--version' not in sys.argv:
    os.execv(os.environ['DEV_TEST_GIT'], [os.environ['DEV_TEST_GIT'], *sys.argv[1:]])
if name == 'fd':
    sys.stdout.buffer.write(os.environ.get('DEV_TEST_PROJECT', '').encode() + b'/.git\\0')
elif name == 'fzf':
    data = sys.stdin.buffer.read()
    if os.environ.get('DEV_TEST_CANCEL'):
        raise SystemExit(130)
    sys.stdout.buffer.write(data)
elif name == os.environ.get('DEV_TEST_FAIL'):
    print('diagnostic failure', file=sys.stderr)
    raise SystemExit(7)
elif name == 'shellcheck':
    print('ShellCheck - shell script analysis tool\\nversion: 1.2.3\\nlicense: test')
else:
    print(name + ' fixture-version')
'''
        for tool in ('node', 'python', 'pnpm', 'bun', 'uv', 'go', 'rustc', 'shellcheck',
                     'shfmt', 'git', 'gh', 'docker', 'lazygit', 'lazydocker', 'xh',
                     'psql', 'redis-cli', 'sqlite3', 'open', 'lsof', 'fd', 'fzf'):
            path = self.bin / tool
            path.write_text(stub)
            path.chmod(0o755)

    def run_dev(self, *args, cwd=None, **env):
        return subprocess.run([BASH, str(ROOT / 'local/bin/mac-dev'), *args],
                              cwd=cwd or self.base, env=dict(self.env, **env),
                              text=True, capture_output=True)

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def repository(self, name='project with spaces'):
        path = self.home / 'Developer' / name
        path.mkdir(parents=True)
        subprocess.run([REAL_GIT, '-c', 'init.defaultBranch=main', 'init', str(path)],
                       env=self.env, check=True, capture_output=True)
        (path / 'example.txt').write_text('untracked test file\n')
        return path

    def test_default_status_only_probes_clients_and_disables_auto_install(self):
        result = self.run_dev()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ShellCheck     1.2.3', result.stdout)
        self.assertIn('Bruno          installed', result.stdout)
        self.assertIn('Postgres', result.stdout)
        self.assertGreaterEqual(len(self.calls()), 18)
        for tool, args, cwd, auto_install in self.calls():
            self.assertEqual(cwd, '/')
            self.assertEqual(auto_install, '0')
            self.assertIn(args, [['--version'], ['version'], ['compose', 'version', '--short']])
            self.assertNotIn(tool, ('open', 'lsof', 'fd', 'fzf'))

    def test_doctor_finishes_after_failure_and_returns_nonzero(self):
        result = self.run_dev('doctor', DEV_TEST_FAIL='pnpm')
        self.assertEqual(result.returncode, 1)
        self.assertIn('FAILED (exit 7): diagnostic failure', result.stdout)
        self.assertIn('DBeaver        installed', result.stdout)
        self.assertIn('sqlite3', [call[0] for call in self.calls()])

    def test_relative_project_path_is_resolved_before_version_probe_changes_directory(self):
        relative = self.base / 'relative tools'
        relative.mkdir()
        (self.bin / 'pnpm').rename(relative / 'pnpm')
        result = self.run_dev('status', PATH=f'relative tools:{self.env["PATH"]}')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(result.stdout, r'pnpm\s+pnpm fixture-version')
        self.assertEqual([call[2] for call in self.calls() if call[0] == 'pnpm'], ['/'])

    def test_missing_command_and_app_are_reported(self):
        (self.bin / 'pnpm').unlink()
        (self.apps / 'Bruno.app/Contents/Info.plist').unlink()
        result = self.run_dev('status')
        self.assertEqual(result.returncode, 1)
        self.assertRegex(result.stdout, r'pnpm\s+MISSING')
        self.assertRegex(result.stdout, r'Bruno\s+MISSING')
        self.assertIn('DBeaver        installed', result.stdout)

    def test_git_reads_real_repository_without_changing_files(self):
        repo = self.repository()
        before = {str(p.relative_to(repo)): p.read_bytes()
                  for p in repo.rglob('*') if p.is_file()}
        result = self.run_dev('git', 'status', str(repo))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('?? example.txt', result.stdout)
        self.assertEqual(before, {str(p.relative_to(repo)): p.read_bytes()
                                  for p in repo.rglob('*') if p.is_file()})
        for action in ('diff', 'worktrees'):
            result = self.run_dev('git', action, str(repo))
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--no-ext-diff', [c for c in self.calls() if 'diff' in c[1]][0][1])

    def test_git_ui_uses_current_repo_or_explicit_directory_without_picker(self):
        repo = self.repository()
        for args, cwd in [(('git', 'ui'), repo), (('git', 'ui', str(repo)), self.base)]:
            with self.subTest(args=args):
                result = self.run_dev(*args, cwd=cwd)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[-1][:3], ['lazygit', [], str(repo.resolve())])
        self.assertNotIn('fzf', [c[0] for c in self.calls()])

    def test_git_ui_picker_preserves_unusual_path_as_data(self):
        repo = self.repository("project 'quoted' ; literal $value\nnext line")
        result = self.run_dev('git', 'ui', DEV_TEST_PROJECT=str(repo))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][:3], ['lazygit', [], str(repo.resolve())])
        fd_args = [c[1] for c in self.calls() if c[0] == 'fd'][0]
        self.assertIn('--print0', fd_args)
        self.assertIn('--max-depth', fd_args)

    def test_picker_cancel_and_invalid_explicit_directory_do_not_launch_ui(self):
        repo = self.repository()
        result = self.run_dev('git', 'ui', DEV_TEST_PROJECT=str(repo), DEV_TEST_CANCEL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('lazygit', [c[0] for c in self.calls()])
        count = len(self.calls())
        result = self.run_dev('git', 'ui', str(self.base))
        self.assertEqual(result.returncode, 2)
        self.assertEqual([c[0] for c in self.calls()[count:]], ['git'])

    def test_bare_repository_is_not_treated_as_a_worktree(self):
        repo = self.base / 'bare.git'
        subprocess.run([REAL_GIT, 'init', '--bare', str(repo)], env=self.env,
                       check=True, capture_output=True)
        result = self.run_dev('git', 'ui', str(repo))
        self.assertEqual(result.returncode, 2)
        self.assertIn('Not a Git worktree', result.stderr)
        self.assertNotIn('lazygit', [c[0] for c in self.calls()])

    def test_explicit_routes_forward_fixed_arguments(self):
        routes = {
            ('docker',): ('docker', ['version']),
            ('docker', 'ps'): ('docker', ['ps', '--all', '--format',
                                         r'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}']),
            ('docker', 'compose'): ('docker', ['compose', 'ls']),
            ('docker', 'ui'): ('lazydocker', []),
            ('db', 'open'): ('open', ['-a', 'DBeaver']),
            ('api', 'open'): ('open', ['-a', 'Bruno']),
            ('ports',): ('lsof', ['-nP', '-iTCP', '-sTCP:LISTEN']),
            ('ports', '08080'): ('lsof', ['-nP', '-iTCP:8080', '-sTCP:LISTEN']),
        }
        for args, (tool, forwarded) in routes.items():
            with self.subTest(args=args):
                result = self.run_dev(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls()[-1][:2], [tool, forwarded])

    def test_rejects_extra_arguments_unknown_actions_and_shell_input(self):
        invalid = [('status', 'extra'), ('doctor', 'extra'), ('help', 'extra'),
                   ('git', 'fetch'), ('docker', 'prune'), ('docker', 'ps', '--all'),
                   ('api', 'open', 'extra'), ('db', 'open', 'extra'), ('db', 'drop'),
                   ('ports', '0'), ('ports', '-1'), ('ports', '65536'),
                   ('ports', '8080; touch unwanted'), ('ports', '999999999999999999'),
                   ('git; touch unwanted',)]
        for args in invalid:
            with self.subTest(args=args):
                self.assertEqual(self.run_dev(*args).returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_child_failure_is_preserved(self):
        result = self.run_dev('docker', 'ps', DEV_TEST_FAIL='docker')
        self.assertEqual(result.returncode, 7)
        self.assertIn('diagnostic failure', result.stderr)

    @unittest.skipUnless(os.access('/usr/sbin/lsof', os.X_OK), 'macOS system lsof required')
    def test_ports_uses_system_lsof_when_gui_path_omits_sbin(self):
        (self.bin / 'lsof').unlink()
        result = self.run_dev('ports', '65535')
        # lsof returns 1 when no process listens on this port. Either outcome
        # proves the installed utility ran instead of failing tool resolution.
        self.assertIn(result.returncode, (0, 1), result.stderr)
        self.assertNotIn('unavailable', result.stderr)


if __name__ == '__main__':
    unittest.main()
