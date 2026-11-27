# Ajazz AK820 Pro 2.4G wireless dongle stops working on Linux: fix

**Problem:** On Linux, the Ajazz AK820 Pro keyboard's 2.4 GHz wireless USB
dongle stops working after the keyboard goes to sleep or has been idle for a
while. Keys stop typing, and the keyboard only comes back after you unplug and
re-plug the dongle or reboot. Turning the keyboard off and on does not help.
On Windows the same dongle works fine.

**Fix:** install the `ak820-dongle-fix` package from this repo (Fedora, Ubuntu,
Debian, Arch, Bazzite and others). It makes Linux read the dongle the way
Windows does, so the wireless connection no longer stalls. No reboot, no
kernel changes, and it removes cleanly.

**Cause:** the dongle (`lsusb`: `ID 0c45:fdfd Microdia 2.4G Dongle`) has two
vendor HID interfaces that nothing on Linux reads. The dongle queues status
messages there, and once they go unread its radio link stalls.
[Details below.](#why-it-happens)

## Do you have this problem?

You very likely do if all of these are true:

- An Ajazz AK820 Pro, connected with its 2.4G USB dongle
- After the keyboard has slept, it stops typing until you re-plug the dongle
- Restarting the keyboard doesn't bring it back
- The same dongle works fine on Windows

Check that you have the same dongle:

```console
$ lsusb | grep 0c45:fdfd
Bus 003 Device 005: ID 0c45:fdfd Microdia 2.4G Dongle
```

In `dmesg` or `journalctl -k` it shows up as:

```
hid-generic 0003:0C45:FDFD.0005: input,hidraw4: USB HID v1.00 Keyboard [2.4G Dongle] on usb-0000:07:00.4-1.3/input0
```

If your dongle has a different ID, this fix will not touch it. Please
[open an issue](https://github.com/druby-luke/ak820-dongle-linux-fix/issues)
with your `lsusb` line.

## Install

### Package (recommended)

Download the package for your distro from the
[latest release](https://github.com/druby-luke/ak820-dongle-linux-fix/releases/latest),
then install it:

| Distro | Install |
|---|---|
| Fedora | `sudo dnf install ./ak820-dongle-fix-*.noarch.rpm` |
| Ubuntu, Debian, Linux Mint, Pop!_OS, Zorin OS | `sudo apt install ./ak820-dongle-fix_*_all.deb` |
| Arch Linux, EndeavourOS, Manjaro, CachyOS | `sudo pacman -U ak820-dongle-fix-*-any.pkg.tar.zst` |

It works straight away, also for a dongle that is already plugged in. Remove
it with your package manager (`dnf remove`, `apt remove`, `pacman -R`
`ak820-dongle-fix`).

### Script (any distro, and Bazzite / Fedora Atomic)

```sh
git clone https://github.com/druby-luke/ak820-dongle-linux-fix
cd ak820-dongle-linux-fix
sudo ./install.sh
```

Undo with `sudo ./uninstall.sh`. Use this on **Bazzite, Fedora Silverblue,
Kinoite** and other image-based systems. It needs no `rpm-ostree` layering and
no reboot, and it survives system updates. Use either the package or the
script, not both.

### Check that it works

```console
$ ak820-dongle-diagnose        # or ./diagnose.sh from the repo
USB 3-1.3: 0c45:fdfd "2.4G Dongle" bcdDevice 0138
  target check: match
  3-1.3:1.0 hidraw4 descriptor: 05 01 09 06 a1 keepalive:active
  3-1.3:1.1 hidraw5 descriptor: 05 01 09 02 a1 keepalive:active
  3-1.3:1.2 hidraw6 descriptor: 05 0c 09 01 a1 keepalive:active
  3-1.3:1.3 hidraw7 descriptor: 06 60 ff 09 61 keepalive:active
  3-1.3:1.4 hidraw8 descriptor: 06 59 ff 09 61 keepalive:active
```

Every interface should say `keepalive:active`. Logs:
`journalctl -u 'ak820-dongle-keepalive@*'`.

## Why it happens

The dongle has five USB HID interfaces:

| Interface | Usage | Read on Linux by |
|---|---|---|
| 0 | Keyboard (boot protocol) | input stack |
| 1 | Mouse | input stack |
| 2 | Media / system keys, NKRO keyboard | input stack |
| 3 | Vendor page `0xFF60`, 32-byte reports | **nothing** |
| 4 | Vendor page `0xFF59`, 64-byte reports | **nothing** |

Linux's `usbhid` driver only polls an interface while a program has it open.
Interfaces 3 and 4 have no keyboard or mouse function, so nothing opens them
and the kernel never reads them. Windows reads every HID interface all the
time.

The dongle does send data on interface 3: a status report (`55 fc 04 00 …`)
each time the keyboard comes back from idle. During one test evening it sent
54 of them. On a normal Linux system these are never collected, and after the
keyboard sleeps the dongle's firmware stalls its wireless link until it loses
power. That is why only re-plugging helps.

With interfaces 3 and 4 kept open, the dongle kept working through every idle
period in testing, including wake-ups after 41 and 67 minutes of sleep.

## How the fix works

A udev rule notices the dongle and starts a small systemd service for each of
its HID interfaces. Each service holds its interface open and reads it,
throwing the data away, which is what Windows does.

- **No kernel parameters, no reboot, no compiled code.** It only needs `sh`,
  `dd` and `od` (coreutils), udev and systemd.
- **Heavily sandboxed.** Each service can only read its own `/dev/hidrawN`
  device and has no network access and no privileges.
- **Stores nothing.** Key presses are read and immediately discarded. Nothing
  is logged or sent anywhere.
- **Plug and play.** It stops cleanly when you unplug the dongle and starts
  again when you plug it back in.

### Which device it touches

`0c45:fdfd` is a generic SONiX/Microdia ID, so the fix only acts on a device
if all of these match:

1. USB ID `0c45:fdfd`
2. USB product name exactly `2.4G Dongle`
3. A vendor interface whose report descriptor starts with `06 60 ff 09 61`
   (`0xFF60`) **and** one that starts with `06 59 ff 09 61` (`0xFF59`)

Anything else is left alone, including the AK820 Pro itself when it is
connected by cable (`0c45:800a`). If some other product does pass all three
checks, the only effect is that its interfaces get read, which Windows does
anyway.

## FAQ

### Why does my Ajazz AK820 Pro stop typing on Linux after sleep?

Its 2.4G dongle stalls when Linux doesn't read its vendor interfaces. See
[Why it happens](#why-it-happens). This package fixes it.

### Why does only unplugging the dongle help, not restarting the keyboard?

The stuck state is inside the dongle, not the keyboard. The dongle stays
connected over USB but stops passing key presses on. Only cutting its power
resets it.

### Why does it work on Windows but not on Linux?

Windows reads every HID interface of a USB device all the time. Linux only
reads the ones a program has open, and nothing opens the dongle's two vendor
interfaces.

### Is this a USB autosuspend or power management problem?

No. Common advice like `usbcore.autosuspend=-1`, TLP settings or turning off
USB power saving does not help here. The dongle is never suspended in the
first place (`power/control` is already `on`).

### Can I fix it with a kernel parameter instead?

Yes, telling `usbhid` to always poll the dongle has the same effect, after a
reboot:

```sh
sudo grubby --update-kernel=ALL --args="usbhid.quirks=0x0c45:0xfdfd:0x00000400"   # Fedora
rpm-ostree kargs --append=usbhid.quirks=0x0c45:0xfdfd:0x00000400                 # Bazzite / Fedora Atomic
```

On other GRUB distros, add the parameter to `GRUB_CMDLINE_LINUX`. `0x400` is
`HID_QUIRK_ALWAYS_POLL`. This can only match on the USB ID, while the package
also checks the device name and descriptors. Use either this or the package,
not both.

### Does it work on Bazzite, Steam Deck or SteamOS?

On Bazzite and other Fedora Atomic systems, yes: use `install.sh`. It writes
only to `/etc` and `/usr/local`, which stay writable. SteamOS is untested.
Where `/usr/local` is read-only, the installer puts the helper in
`/etc/ak820-dongle-fix/` instead.

### Does it work for other keyboards or the AK820 / AK820 Max?

Possibly, if they come with the same dongle. Run `lsusb`: if it shows
`0c45:fdfd Microdia 2.4G Dongle` and `ak820-dongle-diagnose` says
`target check: match`, the fix applies. Please report other models in an
issue so this list can grow.

### Does it log my keystrokes?

No. The service reads the dongle's reports and throws them away immediately.
Nothing is stored, and the service has no network access.

### Will this be fixed in the Linux kernel?

That is the plan: add the dongle to the kernel's HID quirks list
(`HID_QUIRK_ALWAYS_POLL`), so it works everywhere without this package. Until
then, use this fix.

## Not working?

Run `ak820-dongle-diagnose` (or `./diagnose.sh`) and
[open an issue](https://github.com/druby-luke/ak820-dongle-linux-fix/issues)
with its output, your distro, and when the dongle stops working.

`tools/monitor.py` is the script used to find the cause. It logs the vendor
reports in full and, for the keyboard interfaces, only timestamps and lengths
(never which keys were pressed):

```sh
sudo python3 -I tools/monitor.py              # vendor interfaces held open
sudo python3 -I tools/monitor.py --baseline   # stock Linux behaviour, for comparison
```

## Building the packages

`packaging/build.sh` builds the `.rpm`, `.deb` and Arch packages in clean
containers (needs podman or docker) and writes them to `dist/`. Pushing a tag
`vX.Y.Z` that matches `VERSION` makes GitHub Actions build them and attach
them to a release.

## License

MIT
