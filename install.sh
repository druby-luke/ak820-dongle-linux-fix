#!/bin/sh
# Install the AK820 Pro 2.4G receiver fix (udev rule + systemd service).
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }
cd "$(dirname "$0")"

# /usr/local is writable on normal distros and on Fedora Atomic (Bazzite,
# Silverblue, Kinoite: it points to /var/usrlocal). Image-based systems where
# it is read-only (e.g. SteamOS) get the helper in /etc instead.
LIBEXEC=/usr/local/libexec/ak820-dongle-fix
if ! mkdir -p "$LIBEXEC" 2>/dev/null || ! [ -w "$LIBEXEC" ]; then
	LIBEXEC=/etc/ak820-dongle-fix
	echo "/usr/local is read-only, installing the helper to $LIBEXEC"
fi
install -Dm755 src/ak820-dongle-keepalive "$LIBEXEC/ak820-dongle-keepalive"
install -Dm644 src/70-ak820-dongle-keepalive.rules /etc/udev/rules.d/70-ak820-dongle-keepalive.rules
sed "s#/usr/local/libexec/ak820-dongle-fix#$LIBEXEC#" src/ak820-dongle-keepalive@.service \
	>/etc/systemd/system/ak820-dongle-keepalive@.service
chmod 644 /etc/systemd/system/ak820-dongle-keepalive@.service
command -v restorecon >/dev/null 2>&1 && restorecon -R "$LIBEXEC" /etc/udev/rules.d/70-ak820-dongle-keepalive.rules \
	/etc/systemd/system/ak820-dongle-keepalive@.service || true

systemctl daemon-reload
udevadm control --reload

echo "Installed."
# Apply to a receiver that is already plugged in.
if "$LIBEXEC/ak820-dongle-keepalive" trigger; then
	echo "Receiver detected; run ./diagnose.sh to check it is being kept alive."
else
	echo "No receiver plugged in right now; the fix starts automatically when you plug it in."
fi
