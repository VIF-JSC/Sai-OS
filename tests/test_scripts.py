"""Syntax-check every shell script in the repo."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]

SCRIPTS = (
    [ROOT / "saibuild"]
    + sorted((ROOT / "builder").glob("*.sh"))
    + sorted((ROOT / "os/provision.d").glob("*.sh"))
    + [ROOT / "os/rootfs/usr/bin/sai-update",
       ROOT / "os/rootfs/usr/bin/sai-theme-apply",
       ROOT / "os/rootfs/usr/local/bin/sai-input-setup",
       ROOT / "os/rootfs/usr/bin/sai-first-run",
       ROOT / "os/rootfs/usr/bin/sai-install-launcher"]
)


class ShellSyntaxTests(unittest.TestCase):
    def test_all_scripts_parse(self):
        for script in SCRIPTS:
            with self.subTest(script=str(script.relative_to(ROOT))):
                self.assertTrue(script.is_file(), "file does not exist")
                proc = subprocess.run(
                    ["bash", "-n", str(script)], capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)


if __name__ == "__main__":
    unittest.main()
