"""Syntax checks for config files + CLI smoke tests (no build required)."""

from __future__ import annotations

import configparser
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
RFS = ROOT / "os/rootfs"


def parse_ini(path: Path):
    cfg = configparser.RawConfigParser(strict=False)
    cfg.read_string(path.read_text())
    return cfg


class ConfigSyntaxTests(unittest.TestCase):
    def test_dconf_and_gschema_parse(self):
        for p in [RFS / "etc/dconf/db/local.d/00-sai-desktop",
                  RFS / "usr/share/glib-2.0/schemas/99_sai.gschema.override"]:
            with self.subTest(file=p.name):
                parse_ini(p)

    def test_desktop_entries_parse_and_have_exec(self):
        for p in RFS.rglob("*.desktop"):
            with self.subTest(file=str(p.relative_to(RFS))):
                cfg = parse_ini(p)
                self.assertIn("Desktop Entry", cfg)
                self.assertTrue(cfg.get("Desktop Entry", "Exec"))
                self.assertTrue(cfg.get("Desktop Entry", "Type"))

    def test_systemd_units_parse(self):
        for p in (RFS / "usr/lib/systemd/system").glob("sai-*"):
            with self.subTest(file=p.name):
                cfg = parse_ini(p)
                self.assertIn("Unit", cfg)

    def test_json_files_valid(self):
        for p in RFS.rglob("*.json"):
            with self.subTest(file=str(p.relative_to(RFS))):
                json.loads(p.read_text())

    def test_wallpaper_references_exist(self):
        """Every backgrounds/sai/*.png path referenced in config must exist."""
        import re
        refs = set()
        for p in [RFS / "usr/share/glib-2.0/schemas/99_sai.gschema.override",
                  RFS / "etc/lightdm/slick-greeter.conf",
                  RFS / "usr/bin/sai-theme-apply"]:
            refs |= set(re.findall(r"/usr/share/backgrounds/sai/[\w.-]+", p.read_text()))
        self.assertTrue(refs)
        for r in refs:
            self.assertTrue((RFS / r.lstrip("/")).is_file(), f"missing file: {r}")


class CliSmokeTests(unittest.TestCase):
    def test_saibuild_help_runs_without_root(self):
        proc = subprocess.run(["bash", str(ROOT / "saibuild"), "help"],
                              capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("saibuild", proc.stdout)
        for cmd in ("unpack", "provision", "pack", "quick", "clean"):
            self.assertIn(cmd, proc.stdout)

    def test_saibuild_rejects_unknown_flag(self):
        proc = subprocess.run(["bash", str(ROOT / "saibuild"), "--nonsense"],
                              capture_output=True, text=True, cwd=ROOT)
        self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
