#!/bin/sh
# Remove the AK820 Pro 2.4G receiver fix.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./uninstall.sh" >&2; exit 1; }

systemctl stop 'ak820-dongle-keepalive@*.service' 2>/dev/null || true
rm -f /etc/udev/rules.d/70-ak820-dongle-keepalive.rules \
	/etc/systemd/system/ak820-dongle-keepalive@.service
rm -rf /usr/local/libexec/ak820-dongle-fix /etc/ak820-dongle-fix
systemctl daemon-reload
udevadm control --reload
echo "Removed. Re-plug the receiver to return to the default kernel behaviour."
