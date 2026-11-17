#!/usr/bin/env python3
"""Step 1 test for the AK820 Pro 2.4G dongle (0c45:fdfd).

Holds the dongle's HID interfaces open via hidraw so usbhid keeps polling
them, and logs what arrives:
  - if3 / if4 (vendor pages 0xFF60 / 0xFF59): full hex contents
  - if0 - if2 (keyboard / mouse / media keys): ONLY timestamp + length,
    never contents, so no keystrokes are recorded.

Modes:
  (default)    open if0-if4  -> the actual test (vendor interfaces polled)
  --baseline   open if0-if2  -> control run; vendor interfaces stay unpolled,
                                same as normal Linux behaviour

Run:  sudo python3 -I tools/monitor.py [--baseline]
Log:  tools/logs/step1-<mode>-<timestamp>.log
"""
import errno
import glob
import os
import select
import sys
import time

VID, PID = "0c45", "fdfd"
GAP_NOTE = 20  # seconds of silence on input ifaces worth flagging when activity resumes

baseline = "--baseline" in sys.argv
wanted = {0, 1, 2} if baseline else {0, 1, 2, 3, 4}
NAMES = {0: "kbd", 1: "mouse", 2: "media", 3: "vendorFF60", 4: "vendorFF59"}

here = os.path.dirname(os.path.abspath(__file__))
logdir = os.path.join(here, "logs")
os.makedirs(logdir, exist_ok=True)
logpath = os.path.join(
    logdir, f"step1-{'baseline' if baseline else 'test'}-{time.strftime('%Y%m%d-%H%M%S')}.log"
)
logf = open(logpath, "a", buffering=1)
uid, gid = int(os.environ.get("SUDO_UID", -1)), int(os.environ.get("SUDO_GID", -1))
for p in (logdir, logpath):
    try:
        os.chown(p, uid, gid)
    except OSError:
        pass


def log(msg):
    line = f"{time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d} {msg}"
    print(line, flush=True)
    logf.write(line + "\n")


def find_dongle():
    """Return {iface_number: /dev/hidrawN} for the dongle, or {} if absent."""
    for dev in glob.glob("/sys/bus/usb/devices/*"):
        try:
            v = open(f"{dev}/idVendor").read().strip()
            p = open(f"{dev}/idProduct").read().strip()
        except OSError:
            continue
        if (v, p) != (VID, PID):
            continue
        out = {}
        for h in glob.glob(f"{dev}/*:1.*/*/hidraw/hidraw*"):
            iface = int(h.split("/")[-4].split(".")[-1])
            out[iface] = "/dev/" + os.path.basename(h)
        return out
    return {}


def open_all():
    fds = {}
    nodes = find_dongle()
    for iface, node in sorted(nodes.items()):
        if iface not in wanted:
            continue
        try:
            fds[os.open(node, os.O_RDONLY | os.O_NONBLOCK)] = iface
            log(f"opened if{iface} ({NAMES.get(iface, '?')}) = {node}")
        except OSError as e:
            log(f"could not open {node}: {e}")
    return fds


log(f"mode={'BASELINE (vendor ifaces NOT opened)' if baseline else 'TEST (vendor ifaces held open)'}")
log(f"log file: {logpath}")
fds = {}
last_input = time.time()
last_heartbeat = time.time()

try:
    while True:
        if not fds:
            fds = open_all()
            if not fds:
                log("dongle not found, retrying in 2s")
                time.sleep(2)
                continue
            last_input = time.time()

        r, _, _ = select.select(list(fds), [], [], 5)
        now = time.time()
        for fd in r:
            iface = fds[fd]
            try:
                data = os.read(fd, 128)
            except OSError as e:
                if e.errno in (errno.ENODEV, errno.EIO, errno.ENOENT):
                    log(f"if{iface} gone ({e.strerror}) - dongle unplugged/reset?")
                    for f in fds:
                        os.close(f)
                    fds = {}
                    break
                if e.errno == errno.EAGAIN:
                    continue
                raise
            if iface in (3, 4):
                log(f"if{iface} {NAMES[iface]} len={len(data)} data={data.hex(' ')}")
            else:
                gap = now - last_input
                if gap >= GAP_NOTE:
                    log(f"input activity resumed after {gap:.0f}s silence (if{iface})")
                last_input = now
        if now - last_heartbeat >= 60:
            log(f"heartbeat: {now - last_input:.0f}s since last keyboard/mouse report")
            last_heartbeat = now
except KeyboardInterrupt:
    log("stopped by user")
