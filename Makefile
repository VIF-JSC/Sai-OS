# SPDX-License-Identifier: GPL-3.0-or-later
# Sai — shortcuts for ./saibuild. Pass ISO=/path/to/lmde.iso if you already have it.
.PHONY: iso release quick unpack provision overlay pack shell inspect test clean clean-all help

iso:            ## Dev build (lz4, fast)
	sudo ./saibuild all $(ISO)

release:        ## Release build (xz, smaller ISO)
	sudo ./saibuild all --release $(ISO)

quick:          ## Validated rootfs → overlay + repack only
	sudo ./saibuild quick $(ISO)

unpack:         ## Extract the base ISO into build/ for manual edits
	sudo ./saibuild unpack $(ISO)

provision:      ## Install packages + overlay + run os/provision.d/
	sudo ./saibuild provision

overlay:        ## Apply os/rootfs/ onto the rootfs only
	sudo ./saibuild overlay

pack:           ## Compress squashfs + create the ISO from the current workspace
	sudo ./saibuild pack

shell:          ## Enter the rootfs chroot
	sudo ./saibuild shell

inspect:        ## Check the boot branding of the ISO/workspace
	bash builder/inspect-iso.sh $(ISO)

test:           ## Static tests: shellcheck (if installed) + unittest, no build needed
	@command -v shellcheck >/dev/null && shellcheck -S warning -x saibuild builder/*.sh os/provision.d/*.sh \
	    os/rootfs/usr/bin/sai-* os/rootfs/usr/local/bin/sai-* || echo "(shellcheck not installed, skipped)"
	python3 -m unittest discover -s tests -v

clean:          ## Remove the workspace (keep cache + base ISO)
	sudo ./saibuild clean

clean-all:      ## Remove the cache and output ISOs too
	sudo ./saibuild clean-all

help:
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'
