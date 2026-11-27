#!/bin/sh
# Show whether a plugged-in receiver is recognised and kept alive.
# Runs without root. Paste the output when opening an issue.
# Installed by a package as ak820-dongle-diagnose, or run from the repo.
CHECK=
for c in "$(dirname "$0")/src/ak820-dongle-keepalive" \
	/usr/libexec/ak820-dongle-fix/ak820-dongle-keepalive \
	/usr/lib/ak820-dongle-fix/ak820-dongle-keepalive \
	/usr/local/libexec/ak820-dongle-fix/ak820-dongle-keepalive \
	/etc/ak820-dongle-fix/ak820-dongle-keepalive; do
	[ -f "$c" ] && { CHECK=$c; break; }
done
[ -n "$CHECK" ] || { echo "ak820-dongle-keepalive helper not found" >&2; exit 1; }

echo "kernel: $(uname -r)"
any=0
for d in /sys/bus/usb/devices/*; do
	[ "$(cat "$d/idVendor" 2>/dev/null)" = 0c45 ] || continue
	any=1
	echo
	echo "USB ${d##*/}: $(cat "$d/idVendor"):$(cat "$d/idProduct") \"$(cat "$d/product" 2>/dev/null)\" bcdDevice $(cat "$d/bcdDevice" 2>/dev/null)"
	echo "  target check: $(sh "$CHECK" check "$d")"
	for i in "$d"/*:1.*; do
		[ -d "$i" ] || continue
		rd=$(ls "$i"/0003:*/report_descriptor 2>/dev/null | head -n1)
		node=$(ls "$i"/0003:*/hidraw 2>/dev/null | head -n1)
		sig=$([ -n "$rd" ] && od -An -tx1 -N5 "$rd" | tr -d '\n')
		state=
		[ -n "$node" ] && state=$(systemctl is-active "ak820-dongle-keepalive@$node.service" 2>/dev/null)
		echo "  ${i##*/} ${node:-no-hidraw} descriptor:${sig:- none} keepalive:${state:-n/a}"
	done
done
[ "$any" -eq 1 ] || echo "No SONiX (0c45) USB devices found. Is the receiver plugged in?"
