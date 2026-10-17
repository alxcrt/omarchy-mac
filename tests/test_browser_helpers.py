#!/opt/homebrew/bin/python3
"""Browser helpers start with a GUI PATH, without Xcode's Python launcher."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


BIN = Path(__file__).resolve().parents[1] / "local/bin"


class BrowserHelpersTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        stub = self.home / "bin"
        stub.mkdir()
        python = stub / "python3"
        python.write_text("#!/bin/sh\necho unexpected PATH Python >&2\nexit 73\n")
        python.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{stub}:/usr/bin:/bin")

    def run_helper(self, name, *args):
        return subprocess.run(
            [str(BIN / name), *args], env=self.env, input=b"",
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10,
        )

    def test_native_host_handles_browser_eof_with_bare_path(self):
        result = self.run_helper("chromium-native-host")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_list_reads_staged_manifest_with_bare_path(self):
        extensions = self.home / "extensions"
        extension = extensions / "copy-url"
        extension.mkdir(parents=True)
        (extension / "manifest.json").write_text(json.dumps({"name": "Copy URL"}))
        self.env["CHROME_EXT_DIR"] = str(extensions)
        result = self.run_helper("chrome-extensions", "list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"Copy URL", result.stdout)

    def test_verify_reads_fixture_profile_with_bare_path(self):
        profile = self.home / "Library/Application Support/Google/Chrome/Default"
        profile.mkdir(parents=True)
        (profile / "Preferences").write_text(json.dumps({
            "extensions": {"settings": {
                "bgpiichlckmfanooecilcjemknkcpngb": {"manifest": {"name": "Copy URL"}}
            }}
        }))
        result = self.run_helper("chrome-extensions", "verify")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"STATUS=loaded", result.stdout)


if __name__ == "__main__":
    unittest.main()
