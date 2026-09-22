# Sai build environment for non-Debian/Ubuntu hosts (e.g. macOS + Docker).
# Run: docker compose run builder  →  sudo ./saibuild all
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive CI=1 APT_LOCK_TIMEOUT=600

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget file rsync make sudo \
        squashfs-tools xorriso isolinux syslinux-common syslinux-utils \
        locales gnupg unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sai
CMD ["/bin/bash"]
