# Ajazz AK820 Pro 2.4G receiver fix for Linux

Fixes the Ajazz AK820 Pro wireless (2.4 GHz) receiver going dead on Linux after
the keyboard has been asleep. Without the fix, typing stops working and only
comes back after re-plugging the receiver or rebooting; turning the keyboard
off and on does not help. Windows is not affected.

## Cause

The receiver shows up as SONiX `0c45:fdfd` "2.4G Dongle" and has five HID
interfaces:

| Interface | Usage | Opened on Linux by |
|---|---|---|
| 0 | Keyboard (boot) | input stack |
| 1 | Mouse | input stack |
| 2 | Consumer / system control, NKRO keyboard | input stack |
| 3 | Vendor page `0xFF60`, 32-byte reports | **nothing** |
| 4 | Vendor page `0xFF59`, 64-byte reports | **nothing** |

Linux's `usbhid` driver only polls an interface while some program has it
open, so interfaces 3 and 4 are never read. Windows polls every HID interface.

The receiver does send data on interface 3. It sends a status report
(`55 fc 04 00 …`) when the keyboard comes back from idle. In one test evening
it sent 54 of these. On a stock Linux system they are never collected, and
after the keyboard sleeps the receiver's radio link stalls until it is
power-cycled.

With interfaces 3 and 4 held open, the receiver kept working through every
idle period in testing, including wake-ups after 41 and 67 minutes asleep.

## The fix

A udev rule notices the receiver and starts one small systemd service per
HID interface. The service keeps the interface open and reads it, discarding
whatever arrives. This is what Windows does. Nothing is stored or sent
anywhere.

- No kernel parameters, no reboot, no compiled code. It only uses `sh`, `dd`
  and `od` (coreutils), plus udev and systemd.
- The service runs heavily sandboxed. It can read only its own `/dev/hidrawN`
  node and has no network and no capabilities.

### Which device it touches

`0c45:fdfd` is a generic SONiX ID, so the fix checks several things before it
acts. A device is only handled if all of these hold:

1. USB vendor ID `0c45` and product ID `fdfd`
2. USB product string exactly `2.4G Dongle`
3. One interface whose report descriptor starts with `06 60 ff 09 61`
   (vendor page `0xFF60`) **and** one that starts with `06 59 ff 09 61`
   (vendor page `0xFF59`)

Anything else is left alone, including the keyboard itself when it is plugged
in by cable (`0c45:800a`). If another product does pass all three checks, the
effect is only that its interfaces get read, which Windows does anyway.

## Install

```sh
git clone https://github.com/druby-luke/ak820-dongle-linux-fix
cd ak820-dongle-linux-fix
sudo ./install.sh
./diagnose.sh
```

`diagnose.sh` should show `target check: match`, and `keepalive:active` for
every interface:

```
USB 3-1.3: 0c45:fdfd "2.4G Dongle" bcdDevice 0138
  target check: match
  3-1.3:1.0 hidraw4 descriptor: 05 01 09 06 a1 keepalive:active
  ...
  3-1.3:1.3 hidraw7 descriptor: 06 60 ff 09 61 keepalive:active
  3-1.3:1.4 hidraw8 descriptor: 06 59 ff 09 61 keepalive:active
```

Logs: `journalctl -u 'ak820-dongle-keepalive@*'`

## Uninstall

```sh
sudo ./uninstall.sh
```

## Alternative: kernel quirk

The same effect can be had without a service by telling `usbhid` to always
poll the device. This takes effect after a reboot, and it can only match on
vendor and product ID:

```sh
sudo grubby --update-kernel=ALL --args="usbhid.quirks=0x0c45:0xfdfd:0x00000400"   # Fedora
```

```sh
rpm-ostree kargs --append=usbhid.quirks=0x0c45:0xfdfd:0x00000400                 # Bazzite / Fedora Atomic
```

`0x400` is `HID_QUIRK_ALWAYS_POLL`. On distros with GRUB, add the same
parameter to `GRUB_CMDLINE_LINUX` instead. Use either this or the service,
not both.

## Immutable distros (Bazzite, Silverblue, SteamOS)

The installer only writes to `/etc` and `/usr/local`, so it works on
read-only images without layering packages, and it survives image updates.
On Fedora Atomic (Bazzite, Silverblue, Kinoite), `/usr/local` points to the
writable `/var/usrlocal`. Where `/usr/local` is read-only, the installer puts
the helper in `/etc/ak820-dongle-fix/` instead.

## Not working, or a different receiver?

Run `./diagnose.sh` and open an issue with its output, your distro, and when
the receiver stops working. `tools/monitor.py` is the script used to find the
cause. It logs the vendor reports in full and, for the keyboard interfaces,
only timestamps and lengths (never key contents):

```sh
sudo python3 -I tools/monitor.py              # vendor interfaces held open
sudo python3 -I tools/monitor.py --baseline   # stock behaviour, for comparison
```

## License

MIT
