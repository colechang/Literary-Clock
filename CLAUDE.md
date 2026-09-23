# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Firmware/scripts that turn a jailbroken Kobo Touch N905C eReader into a literary clock: every minute it displays a random book quote containing the current time (e.g. "one o'clock"), rendered to the eInk screen via FBInk. It also shows weather from wttr.in. This is not a conventional buildable project — it's a set of POSIX shell scripts and one C program deployed onto embedded Linux (kernel 2.6.35, BusyBox, ARMv7/i.MX507), plus a 3000+ row quote dataset.

There is no package manager or unit-test framework. There is a `Makefile` with
three entry points that stand in for one, all runnable on a workstation:

- `make check` — syntax-checks every shell script and validates `quotes.csv`
  (`tools/validate_quotes.sh`). Run this before any change to the dataset or the
  scripts; dataset faults fail silently on the device.
- `make preview` — runs the real `litclock.sh` against `tools/fbink-stub`, which
  prints to the terminal. `litclock.sh` reads `LITCLOCK_FBINK`, `LITCLOCK_CSV`
  and `LITCLOCK_FONTS` so the loop can be exercised off-device.
- `make deploy KOBO=<ip>` — runs `check`, then scp's the scripts and data.

Anything touching the framebuffer, input devices or boot/mount logic still has
to be confirmed on the physical device.

## Architecture / boot chain

```
udev (loop0 event)
  -> /usr/local/stuff/bin/stuff.sh                  (installed by NiLuJe's usbnet package, provided here as usr/local/stuff/bin/stuff.sh)
       -> litclock-start.sh   (backgrounded via setsid)
            - waits up to 30s for the SD card (mmcblk1p1) to mount
            - sleeps 15s, then kills nickel/sickel/sickel-launcher (stock Kobo UI)
            - remounts /mnt/sd read-write
            - syncs time via ntpd if WiFi is reachable
            - sets framebuffer rotation (landscape)
            - shows a startup splash via FBInk
            - launches touch_watcher and litclock.sh as background daemons,
              each under litclock-run.sh
```

- **`litclock.sh`** — the main loop. Once per minute: greps `quotes.csv` for lines matching the current `HH:MM`, picks one at random, highlights the matched time phrase in the quote text, and renders quote + attribution to the eInk framebuffer via the `fbink` binary. Refetches weather from wttr.in once an hour (cached to `/tmp/weather_cache.txt`), switches font size based on quote length, switches to a night-mode inverted render between 22:00–06:00, does a full flashing refresh every 5 wall-clock minutes to prevent eInk ghosting, and polls for a touch-triggered refresh flag once per second while waiting out the rest of the minute.
- **`touch_watcher.c`** (compiled to a static ARM binary, committed as `touch_watcher`) — polls `/dev/input/event1` for touch-down events (BTN_TOUCH, with an ABS_PRESSURE fallback), debounces (2s), and on a valid touch creates `/tmp/litclock_refresh` so `litclock.sh` re-renders early. This is the current/preferred implementation.
- **`touch_watcher.sh`** — an earlier, simpler shell-based touch watcher using blocking `dd` reads on the raw input device. Superseded by `touch_watcher.c` but kept in the repo.
- **`litclock-run.sh`** — respawn supervisor. Runs its argument forever, restarting it on exit with exponential backoff (capped at 60s) and a line in `/tmp/litclock.log`. Both daemons run under it, because a crashed clock leaves a frozen eInk screen that looks identical to a working one.
- **`tools/validate_quotes.sh`** — dataset integrity check. **`tools/fbink-stub`** — terminal stand-in for `fbink`.
- **`quotes.csv`** — pipe-delimited dataset: `HH:MM|time phrase|full quote text|Book Title|Author Name`. This is the data `litclock.sh` greps by exact `HH:MM` prefix.

Everything runs off an SD card (`/mnt/sd`) mounted read-only by default — always `mount -o remount,rw /mnt/sd` before editing files there.

## Working with this repo

- Deploying changes: `make deploy KOBO=<ip>`, which validates first. A single file by hand: `scp litclock.sh root@KOBO_IP:/mnt/sd/litclock.sh`. Changes take effect on the next minute cycle, no reboot needed.
- Compiling the touch watcher requires an ARM cross-compiler: `make watcher CC=arm-linux-musleabihf-gcc` (static musl build; see the header comment in `touch_watcher.c`).
- Manual start/stop and status-check commands (for use over telnet/SSH on the device) are documented in README.md under "Key Commands".
- `stuff.sh` (under `usr/local/stuff/bin/`) mirrors the udev boot-hook entry point installed on the device by NiLuJe's usbnet package — it is tracked here for reference, not built.
- When tearing down the daemons by hand, `killall litclock-run.sh` **first** — it is the supervisor and will otherwise restart whatever you just killed.

## Gotchas worth knowing before changing boot/mount logic

- Never press Home+Power together on the device — triggers a recovery-partition reformat.
- Don't install untested `KoboRoot.tgz` packages — a bad `rcS` causes a boot loop.
- `hindenburg` is a watchdog binary that monitors `nickel`; deleting it causes the device to reboot after ~1 minute, so scripts that kill `nickel` must not also touch `hindenburg`.

## Gotchas in the scripts themselves

- The highlight phrase is injected with `sed`, so it must be escaped as a **POSIX BRE**: only `\ . [ ] * ^ $` are special. Escaping `( ) + ? { }` or `|` *creates* metacharacters and silently drops the highlight. `tools/validate_quotes.sh` checks that every phrase occurs verbatim in its quote.
- `fbink` is invoked with `format`, which reads `*`/`**`/`***` as emphasis, so a literal asterisk in a quote garbles the render. The validator flags these.
- `quotes.csv` is pipe-delimited with no quoting, so a stray newline in the source data joins two records into one 7-field row: the quote gets truncated and the book/author come from the wrong record. The validator flags any row whose field count isn't 5.
- `touch_watcher` is a committed ARM binary; the device has no toolchain. `make watcher` needs an ARM cross-compiler and is deliberately not wired to the default target, so a rebuild can't clobber it by accident.
