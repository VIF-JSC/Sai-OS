"""Static checks for the cloud image variant (os/cloud/, builder/cloud.sh)."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
CLOUD = ROOT / "os/cloud"
CRFS = CLOUD / "rootfs"


def env_default(name: str) -> str:
    """Value of a builder/env.sh setting with a clean environment."""
    proc = subprocess.run(
        ["bash", "-c", f'source builder/env.sh && printf %s "${name}"'],
        capture_output=True, text=True, cwd=ROOT, env={"PATH": "/usr/bin:/bin"})
    return proc.stdout


class CloudImageTests(unittest.TestCase):
    def test_default_output_is_raw(self):
        self.assertEqual(env_default("CLOUD_FORMATS"), "raw")

    def test_provision_scripts_ordered_executable_and_seal_last(self):
        scripts = sorted((CLOUD / "provision.d").glob("*.sh"))
        self.assertGreaterEqual(len(scripts), 4)
        for s in scripts:
            self.assertTrue(s.stat().st_mode & 0o111, f"{s.name} is not executable")
            self.assertTrue(s.name[:2].isdigit(), f"{s.name} lacks an order prefix")
        self.assertIn("seal", scripts[-1].name, "the seal step must run last")

    def test_required_packages_listed(self):
        pkgs = {l.strip() for l in (CLOUD / "packages.txt").read_text().splitlines()
                if l.strip() and not l.startswith("#")}
        for p in ("cloud-init", "cloud-guest-utils", "openssh-server",
                  "qemu-guest-agent", "grub-pc-bin", "grub-efi-amd64-bin"):
            self.assertIn(p, pkgs)

    def test_cloud_init_config(self):
        text = (CRFS / "etc/cloud/cloud.cfg.d/90-sai.cfg").read_text()
        self.assertNotIn("\t", text, "YAML must not contain tabs")
        try:
            import yaml  # optional on CI
        except ImportError:
            yaml = None
        if yaml:
            cfg = yaml.safe_load(text)
            self.assertEqual(cfg["growpart"]["mode"], "auto")
            self.assertTrue(cfg["resize_rootfs"])
            self.assertTrue(cfg["ssh_pwauth"])
            self.assertEqual(cfg["system_info"]["default_user"]["name"], "saiadmin")
            self.assertFalse(cfg["system_info"]["default_user"]["lock_passwd"])
            self.assertEqual(cfg["datasource_list"][-1], "None")
        else:
            for needle in ("growpart:", "mode: auto", "resize_rootfs: true",
                           "ssh_pwauth: true", "datasource_list:",
                           "name: saiadmin", "lock_passwd: false"):
                self.assertIn(needle, text)

    def test_serial_console_enabled(self):
        grub = (CRFS / "etc/default/grub.d/90-sai-cloud.cfg").read_text()
        self.assertIn("console=ttyS0", grub)

    def test_initramfs_has_cloud_disk_drivers(self):
        mods = (CRFS / "usr/share/initramfs-tools/modules.d/sai-cloud").read_text().split()
        for m in ("virtio_blk", "virtio_scsi", "nvme", "ena", "hv_storvsc", "vmw_pvscsi"):
            self.assertIn(m, mods)

    def test_sshd_no_root_login(self):
        conf = (CRFS / "etc/ssh/sshd_config.d/50-sai-cloud.conf").read_text()
        self.assertIn("PermitRootLogin no", conf)
        # password auth is left to cloud-init's ssh_pwauth
        self.assertNotIn("PasswordAuthentication", conf)

    def test_saibuild_help_lists_cloud(self):
        proc = subprocess.run(["bash", str(ROOT / "saibuild"), "help"],
                              capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("cloud", proc.stdout)


if __name__ == "__main__":
    unittest.main()
