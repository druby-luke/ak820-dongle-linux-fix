#!/bin/sh
# Install the AK820 Pro 2.4G receiver fix (udev rule + systemd service).
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }
cd "$(dirname "$0")"

LIBEXEC=/usr/local/libexec/ak820-dongle-fix
install -Dm755 src/ak820-dongle-keepalive "$LIBEXEC/ak820-dongle-keepalive"
install -Dm644 src/70-ak820-dongle-keepalive.rules /etc/udev/rules.d/70-ak820-dongle-keepalive.rules
install -Dm644 src/ak820-dongle-keepalive@.service /etc/systemd/system/ak820-dongle-keepalive@.service
command -v restorecon >/dev/null 2>&1 && restorecon -R "$LIBEXEC" /etc/udev/rules.d/70-ak820-dongle-keepalive.rules \
	/etc/systemd/system/ak820-dongle-keepalive@.service || true

systemctl daemon-reload
udevadm control --reload

# Apply to a receiver that is already plugged in.
found=0
for h in /sys/class/hidraw/hidraw*; do
	[ -e "$h" ] || continue
	usb=$(readlink -f "$h/device/../..")
	[ "$(cat "$usb/idVendor" 2>/dev/null):$(cat "$usb/idProduct" 2>/dev/null)" = "0c45:fdfd" ] || continue
	udevadm trigger --action=add "$h"
	found=1
done
udevadm settle || true

echo "Installed."
if [ "$found" -eq 1 ]; then
	echo "Receiver detected; run ./diagnose.sh to check it is being kept alive."
else
	echo "No receiver plugged in right now; the fix starts automatically when you plug it in."
fi
