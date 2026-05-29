/*
 * touch_watcher.c
 * Literary Clock Touch Watcher
 *
 * Listens for touch events on /dev/input/event1 and creates
 * /tmp/litclock_refresh when a touch is detected.
 *
 * Compile for ARM (Kobo Touch N905C):
 *   arm-linux-gnueabihf-gcc -o touch_watcher touch_watcher.c
 *
 * Or cross-compile with musl for a fully static binary:
 *   arm-linux-musleabihf-gcc -static -o touch_watcher touch_watcher.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <poll.h>
#include <linux/input.h>
#include <sys/stat.h>
#include <errno.h>

/* Config */
#define INPUT_DEVICE    "/dev/input/event1"
#define REFRESH_FLAG    "/tmp/litclock_refresh"
#define TOUCH_LOG       "/tmp/touch_watcher.log"
#define DEBOUNCE_MS     2000   /* milliseconds between accepted touches */

/* Global fd so signal handler can close it cleanly */
static int input_fd = -1;
static FILE *log_fp = NULL;

/* ------------------------------------------------------------------ */
/* Logging                                                              */
/* ------------------------------------------------------------------ */

static void log_msg(const char *msg)
{
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char buf[32];
    strftime(buf, sizeof(buf), "%H:%M:%S", t);

    if (log_fp) {
        fprintf(log_fp, "[%s] %s\n", buf, msg);
        fflush(log_fp);
    }
}

/* ------------------------------------------------------------------ */
/* Signal handling — clean shutdown                                     */
/* ------------------------------------------------------------------ */

static void handle_signal(int sig)
{
    (void)sig;
    log_msg("Touch watcher shutting down");
    if (input_fd >= 0)
        close(input_fd);
    if (log_fp)
        fclose(log_fp);
    exit(0);
}

/* ------------------------------------------------------------------ */
/* Create the refresh flag file                                         */
/* ------------------------------------------------------------------ */

static void create_refresh_flag(void)
{
    int fd = open(REFRESH_FLAG, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        log_msg("ERROR: could not create refresh flag");
        return;
    }
    close(fd);
    log_msg("Touch detected — refresh flag created");
}

/* ------------------------------------------------------------------ */
/* Returns monotonic time in milliseconds                               */
/* ------------------------------------------------------------------ */

static long long now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000LL + ts.tv_nsec / 1000000LL;
}

/* ------------------------------------------------------------------ */
/* Main                                                                 */
/* ------------------------------------------------------------------ */

int main(void)
{
    struct input_event ev;
    struct pollfd pfd;
    long long last_touch_ms = 0;
    int touch_active = 0;

    /* Open log */
    log_fp = fopen(TOUCH_LOG, "a");
    if (!log_fp) {
        fprintf(stderr, "touch_watcher: could not open log file\n");
        /* Non-fatal — continue without logging */
    }

    log_msg("Touch watcher started");

    /* Set up signal handlers for clean shutdown */
    signal(SIGTERM, handle_signal);
    signal(SIGINT,  handle_signal);
    signal(SIGHUP,  handle_signal);

    /* Open input device */
    input_fd = open(INPUT_DEVICE, O_RDONLY | O_NONBLOCK);
    if (input_fd < 0) {
        log_msg("ERROR: could not open " INPUT_DEVICE);
        fprintf(stderr, "touch_watcher: cannot open %s: %s\n",
                INPUT_DEVICE, strerror(errno));
        return 1;
    }

    log_msg("Listening on " INPUT_DEVICE);

    pfd.fd     = input_fd;
    pfd.events = POLLIN;

    /* ---- Main event loop ------------------------------------------ */
    while (1) {
        /* Block until an event arrives (or timeout after 5s to stay alive) */
        int ret = poll(&pfd, 1, 5000);

        if (ret < 0) {
            if (errno == EINTR)
                continue;   /* interrupted by signal, loop again */
            log_msg("ERROR: poll() failed");
            break;
        }

        if (ret == 0)
            continue;   /* timeout, no event — loop again */

        /* Read one input_event struct */
        ssize_t n = read(input_fd, &ev, sizeof(ev));
        if (n < (ssize_t)sizeof(ev))
            continue;

        /*
         * The zForce IR touch controller on the N905C reports:
         *   EV_KEY / BTN_TOUCH (type=1, code=330) value=1  -> finger down
         *   EV_KEY / BTN_TOUCH (type=1, code=330) value=0  -> finger up
         *   EV_ABS / ABS_PRESSURE (type=3, code=24)        -> pressure
         *
         * We trigger on BTN_TOUCH value=1 (finger down) with debounce.
         */

        if (ev.type == EV_KEY && ev.code == BTN_TOUCH) {
            if (ev.value == 1 && !touch_active) {
                /* Finger down */
                touch_active = 1;
                long long now = now_ms();

                if (now - last_touch_ms >= DEBOUNCE_MS) {
                    last_touch_ms = now;
                    create_refresh_flag();
                } else {
                    log_msg("Touch ignored (debounce)");
                }
            } else if (ev.value == 0) {
                /* Finger up */
                touch_active = 0;
            }
        }

        /*
         * Fallback: also catch pressure-based touches for devices
         * that don't reliably send BTN_TOUCH events.
         * Only trigger on pressure > 0 transitioning from 0.
         */
        if (ev.type == EV_ABS && ev.code == ABS_PRESSURE) {
            static int last_pressure = 0;
            int pressure = ev.value;

            if (pressure > 0 && last_pressure == 0) {
                /* Pressure just went non-zero — treat as touch */
                long long now = now_ms();
                if (now - last_touch_ms >= DEBOUNCE_MS && !touch_active) {
                    last_touch_ms = now;
                    create_refresh_flag();
                }
            }
            last_pressure = pressure;
        }
    }

    /* Clean up */
    close(input_fd);
    log_msg("Touch watcher exited");
    if (log_fp)
        fclose(log_fp);

    return 0;
}
