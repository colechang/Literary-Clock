/*
 * Minimal stand-in for <linux/input.h>, so touch_watcher.c can be compile- and
 * type-checked on a workstation that has no Linux headers and no ARM
 * toolchain. `make check` uses this; it only ever runs the compiler's front
 * end (-fsyntax-only) and never produces a runnable binary.
 *
 * The real build is `make watcher CC=arm-linux-musleabihf-gcc`, against the
 * actual kernel headers.
 */
#ifndef _SHIM_LINUX_INPUT_H
#define _SHIM_LINUX_INPUT_H

#include <sys/time.h>

struct input_event {
    struct timeval time;
    unsigned short type;
    unsigned short code;
    int            value;
};

#define EV_KEY        0x01
#define EV_ABS        0x03
#define BTN_TOUCH     0x14a
#define ABS_PRESSURE  0x18

#endif /* _SHIM_LINUX_INPUT_H */
