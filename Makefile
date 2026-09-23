# The Kobo runs an ARMv7 (i.MX507) userland on Linux 2.6.35, so touch_watcher
# has to be cross-compiled. The checked-in `touch_watcher` binary is a static
# PIE build; it is committed because the device has no toolchain and nothing
# else here needs building.
#
#   make check      validate quotes.csv and syntax-check every shell script
#   make watcher    cross-compile touch_watcher (static, stripped)
#   make preview    run the real clock loop locally against a stubbed fbink
#   make deploy KOBO=192.168.1.42    push the scripts and data to the device

CC      ?= arm-linux-musleabihf-gcc
# Host compiler, only ever used to syntax-check touch_watcher.c against the
# stub headers in tools/shim. Never produces a binary for the device.
HOSTCC  ?= cc
CFLAGS  ?= -static -Os -s -Wall -Wextra
KOBO    ?= kobo
SDCARD  ?= /mnt/sd

SCRIPTS = litclock.sh litclock-start.sh litclock-run.sh litclock-drain.sh \
          touch_watcher.sh \
          tools/validate_quotes.sh tools/fbink-stub

.PHONY: all
all: check

# Not wired to the touch_watcher file itself: the committed binary is the only
# copy most machines can produce, and an accidental rebuild without the ARM
# toolchain would clobber it.
.PHONY: watcher
watcher:
	$(CC) $(CFLAGS) -o touch_watcher touch_watcher.c

# No cross-toolchain needed. Alpine is musl-based, so compiling natively inside
# an armv7 Alpine container produces exactly the static musl ARM binary the
# device needs. This matters because the Kobo runs kernel 2.6.35 and a modern
# glibc static binary requires 3.2+, which is why musl is not optional here.
.PHONY: watcher-docker
watcher-docker:
	docker run --rm --platform linux/arm/v7 -v "$$PWD":/src -w /src alpine:3.19 \
		sh -c 'apk add --no-cache build-base linux-headers >/dev/null 2>&1 && \
		       gcc $(CFLAGS) -o touch_watcher touch_watcher.c'
	@file touch_watcher

.PHONY: check
check:
	@for s in $(SCRIPTS); do sh -n "$$s" || exit 1; done
	@echo "shell syntax OK"
	@if command -v $(HOSTCC) >/dev/null 2>&1; then \
		$(HOSTCC) -Itools/shim -Wall -Wextra -fsyntax-only touch_watcher.c && \
		echo "touch_watcher.c compiles clean"; \
	else echo "no host compiler, skipping touch_watcher.c check"; fi
	@./tools/validate_quotes.sh quotes.csv

.PHONY: preview
preview:
	LITCLOCK_FBINK=./tools/fbink-stub LITCLOCK_CSV=./quotes.csv ./litclock.sh

# Changes take effect on the next minute cycle; no reboot needed.
.PHONY: deploy
deploy: check
	ssh root@$(KOBO) 'mount -o remount,rw $(SDCARD)'
	scp litclock.sh litclock-run.sh litclock-drain.sh touch_watcher quotes.csv root@$(KOBO):$(SDCARD)/
	scp litclock-start.sh root@$(KOBO):/usr/local/stuff/bin/
	@echo "Deployed. Restart with: ssh root@$(KOBO) /usr/local/stuff/bin/litclock-start.sh"
