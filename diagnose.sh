#!/bin/sh
# Show whether a plugged-in receiver is recognised and kept alive.
# Runs without root. Paste the output when opening an issue.
cd "$(dirname "$0")"
CHECK=src/ak820-dongle-keepalive

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
