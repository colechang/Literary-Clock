# Literary Clock

An old Kobo eReader repurposed as a literary clock: every minute it shows a
book quote containing the current time, plus the local weather. Tap the screen
for a different quote for the same minute.

Nothing is permanent — remove the startup hook and reboot to get the stock
Kobo back.

<div align="center">
<table>
  <tr>
    <td><img src="images/lightmode_litclock.jpg" height="500"></td>
    <td><img src="images/darkmode_litclock.jpg" height="500"></td>
  </tr>
</table>
<em>The dead pixels in the center are from a drop, not the software.</em>
</div>

## Device

Kobo Touch N905C (i.MX507 ARMv7, 600x800 eInk, Linux 2.6.35, BusyBox), with an
SD card holding the scripts and data.

## How it works

On boot, a udev hook (`stuff.sh`, from NiLuJe's usbnet package) launches
`litclock-start.sh`, which waits for the SD card, stops the stock Kobo UI
(`nickel`), rotates the screen to landscape and starts the daemons under the
`litclock-run.sh` respawn supervisor:

- `litclock.sh` — the clock loop. Picks a random quote for the current `HH:MM`
  from `quotes.csv`, renders it with FBInk, refetches weather from `wttr.in`
  hourly, inverts the screen at night, and does a full refresh every 5 minutes
  to clear eInk ghosting.
- `touch_watcher` — compiled from `touch_watcher.c`; signals the clock to
  redraw when the screen is tapped.
- `litclock-drain.sh` — reads nickel's hardware-status FIFO so stock event
  handlers don't hang once nickel is gone.

## Setup

1. Install [NiLuJe's USBNet/SSH package](https://www.mobileread.com/forums/showthread.php?t=254214)
   (copy `KoboRoot.tgz` to `/mnt/onboard/.kobo/` and reboot). It provides SSH,
   FBInk and the boot hook.
2. Put the FBInk binary and NotoSerif fonts under `/mnt/sd/koreader/` (both
   ship with KOReader).
3. Replace `/usr/local/stuff/bin/stuff.sh` on the device with
   `usr/local/stuff/bin/stuff.sh` from this repo, which adds the clock launch.
4. From your computer: `make deploy KOBO=<ip>` (copies everything else,
   including `litclock-start.sh`).

Set `CITY` in `litclock.sh` for your weather; the font variables at the top of
the same file control the typeface.

## Development

```sh
make check     # syntax-check scripts and validate quotes.csv
make preview   # run the clock loop in your terminal with a stub fbink
make deploy KOBO=<ip>
make watcher-docker   # rebuild touch_watcher (static musl ARM) without a toolchain
```

Changes take effect on the next minute, no reboot needed. `quotes.csv` is
pipe-delimited:

```
HH:MM|time phrase|full quote text|Book Title|Author Name
```

## On the device

The SD card mounts read-only; run `mount -o remount,rw /mnt/sd` before editing
anything on it. To restart the clock by hand (kill the supervisor first, or it
restarts whatever you kill):

```sh
killall litclock-run.sh litclock.sh touch_watcher litclock-drain.sh nickel sickel sickel-launcher 2>/dev/null
mount -o remount,rw /mnt/sd
setsid nohup /mnt/sd/litclock-run.sh /mnt/sd/litclock-drain.sh > /dev/null 2>&1 &
setsid nohup /mnt/sd/litclock-run.sh /mnt/sd/touch_watcher > /dev/null 2>&1 &
setsid nohup /mnt/sd/litclock-run.sh /mnt/sd/litclock.sh 2>> /tmp/litclock.log &
```

Logs go to `/tmp/litclock.log`.

## Warnings

- **Never press Home + Power together** — it triggers a recovery reformat that
  wipes your changes.
- **Don't install untested `KoboRoot.tgz` packages** — a bad `rcS` means a boot
  loop.
- **Don't delete `hindenburg`** — it's nickel's watchdog; the device reboots
  about a minute later.

Old firmware for recovery: [pgaskin.net/KoboStuff](https://pgaskin.net/KoboStuff/kobofirmware.html).

## License

The code is MIT. The quote dataset descends from the Guardian's crowd-sourced
collection and stays under CC BY-NC-SA 2.5 (non-commercial, share-alike,
attribution required). See [LICENSE](LICENSE).

## Credits

- **FBInk** and the **usbnet package** by NiLuJe
- **Quotes** from Jaap Meijers's dataset (originally the Guardian's), with gaps
  filled from [JohannesNE](https://github.com/JohannesNE/literature-clock),
  [cdmoro](https://github.com/cdmoro/literature-clock) and
  [kapoorankush](https://github.com/kapoorankush/litclock)
- **KOReader** for the prebuilt FBInk binary and NotoSerif fonts
