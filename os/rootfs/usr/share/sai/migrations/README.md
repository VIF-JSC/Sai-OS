# Sai migrations

Each `NN-short-name.sh` in this directory runs **exactly once** per machine, in filename
order, driven by `sai-update` (daily timer).

- On success the filename is appended to `/var/lib/sai/migrations.done`.
- On failure the chain stops and is retried on the next update; write migrations to be idempotent.

## Distribution

Package new migrations in a deb (for example `sai-config`) that installs files into this
directory, and publish it to your APT repository (`/etc/apt/sources.list.d/sai.sources`).
Installed machines receive the package through `apt full-upgrade`, then `sai-update`
runs the new migrations.

## Example

```bash
#!/bin/bash
# 01-change-wallpaper.sh — change the default wallpaper on every machine
set -e
cp /usr/share/backgrounds/sai/new-year-2027.png /usr/share/backgrounds/sai/default.png
dconf update
```
