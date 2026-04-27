# Kobo Touch N905C Literary Clock

A literary clock for the Kobo that displays time-matched literary quotes on the eInk screen using a custom Linux shell script and FBInk.

---

## Device

- **Model:** Kobo Touch N905C (Trilogy @ Mark 4)
- **CPU:** i.MX507 ARMv7
- **Screen:** 600x800 eInk, 167 dpi
- **Kernel:** Linux 2.6.35.3 (BusyBox v1.35.99.139-g15f7d618e)

---

## How It Works

On boot, the device runs `stuff.sh` via a udev hook (provided by NiLuJe's usbnet package). This launches `litclock-start.sh`, which waits for the SD card to mount, kills the Kobo UI (nickel), and starts the clock script. The clock script reads `quotes.csv` every minute, finds a matching literary quote for the current time, and renders it to the eInk screen using FBInk.

---

## File Layout

Easier to use a SD card due to the limited onboard memory
| File | Location | Description |
|------|----------|-------------|
| Main clock script | `/mnt/sd/litclock.sh` | The main clock loop |
| Quotes database | `/mnt/sd/quotes.csv` | Time-tagged literary quotes |
| Boot entry point | `/usr/local/stuff/bin/stuff.sh` | Runs at boot via udev |
| Boot launcher | `/usr/local/stuff/bin/litclock-start.sh` | Waits for SD, kills nickel, starts clock |
| FBInk binary | `/mnt/sd/koreader/fbink` | Writes text to the eInk framebuffer |
| Fonts | `/mnt/sd/koreader/fonts/noto/` | NotoSerif Regular/Bold/Italic/BoldItalic |

---

## Key Commands

### Manually start the clock (from telnet/SSH)

```sh
killall nickel 2>/dev/null
killall sickel 2>/dev/null
mount -o remount,rw /mnt/sd
setsid nohup /mnt/sd/litclock.sh > /tmp/litclock.log 2>&1 &
```

### Check if the clock is running

```sh
ps | grep litclock
```

### Remount SD card as writable

```sh
mount -o remount,rw /mnt/sd
```

> The SD card mounts read-only by default. You must remount it before writing or editing any files on it.

### Update the clock script or quotes

```sh
# SCP from your PC
scp litclock.sh root@KOBO_IP:/mnt/sd/litclock.sh
scp quotes.csv root@KOBO_IP:/mnt/sd/quotes.csv
```

Changes take effect on the next minute cycle — no reboot needed.

---

## quotes.csv Format

The CSV uses `|` as a separator with five columns:

```
HH:MM|time phrase|full quote text|Book Title|Author Name
```

Example:

```
13:00|one o'clock|Czarina Catherine reported entering Galatz at one o'clock today.|Dracula|Bram Stoker
```

---

## Extra Fonts

You can try more fonts by adding them to the /mnt/sd/fonts and altering the font constants in `litclock.sh`

- `$REGULAR`
- `$BOLD`
- `$ITALIC`
- `$BOLDITALIC`

---

## Boot Chain

```
udev (loop0 event)
  └── /usr/local/stuff/bin/stuff.sh
        └── /usr/local/stuff/bin/litclock-start.sh  (backgrounded with setsid)
              ├── waits for /mnt/sd to mount
              ├── sleeps 15s for nickel to start
              ├── killall nickel / sickel / sickel-launcher
              ├── mount -o remount,rw /mnt/sd
              └── setsid nohup /mnt/sd/litclock.sh > /tmp/litclock.log 2>&1 &
```

---

## Burn-in / Ghosting Prevention

The script performs a full flashing screen refresh (`fbink -f -k`) every 5 minutes to clear eInk ghosting. This is normal — the screen will flash black briefly then return to the quote.

---

## Required Packages

### NiLuJe's USB Net / Telnet / SSH package

**https://www.mobileread.com/forums/showthread.php?t=254214**

- Necessary for telnet and SSH access to the device
- Contains FBInk — the binary responsible for writing custom quotes to the eInk screen
- Provides the `stuff.sh` udev boot hook used for autostart
- Install by copying `KoboRoot.tgz` to `/mnt/onboard/.kobo/` and rebooting
- Does **not** touch `rcS`, `inittab`, or any system files! I learned that the hard way.

---

## Kobo Firmware Archive

**https://pgaskin.net/KoboStuff/kobofirmware.html**

Historical Kobo firmware versions for all devices. Useful if you need to restore or identify the correct firmware version for your device.

---

## Warnings & Gotchas

- **Do NOT press Home + Power together** — this triggers the recovery partition (sda2) which reformats sda1 and wipes all your changes
- **Do NOT put untested KoboRoot.tgz files in `.kobo/`** — a bad rcS will cause a boot loop that requires manually mounting sda1 on a PC to fix
- **The SD card mounts read-only** — always run `mount -o remount,rw /mnt/sd` before editing files on it
- **hindenburg** is the watchdog binary that monitors nickel— do not delete it or the device will reboot after ~1 minute

---

## More E-reader Jailbreaks

If you need more e-reader hacks, tools, and community support:

**https://www.mobileread.com/**

---

## Credits

- **FBInk** by NiLuJe — eInk framebuffer writing library
- **Literary clock quotes** based on Jaap Meijers's dataset
- **NiLuJe's usbnet/KoboStuff package** — telnet, SSH, and boot hook infrastructure
- **KoReader** — provided the pre-compiled FBInk binary and NotoSerif fonts
