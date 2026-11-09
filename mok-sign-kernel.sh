#!/bin/bash
#
# mok-sign-kernel.sh - sign a kernel image (vmlinuz / EFI PE) with the MOK
#
# Appends an Authenticode signature with the MOK so shim will load the kernel
# under Secure Boot.  Signs in place (keeps the same filename) and is
# idempotent - an image already signed by the MOK is left alone.
#
# Usage: mok-sign-kernel.sh <vmlinuz> [<vmlinuz> ...]
#
# Env:
#   MOK_DIR   default /etc/pki/mok   (expects MOK.key, MOK.crt)
#
# Must run as root (reads the 0600 MOK key, writes /boot).
set -euo pipefail

MOK_DIR="${MOK_DIR:-/etc/pki/mok}"
key="$MOK_DIR/MOK.key"
crt="$MOK_DIR/MOK.crt"

if [[ $# -lt 1 ]]; then
	echo "usage: $0 <vmlinuz> [...]" >&2
	exit 2
fi
command -v sbsign >/dev/null 2>&1 || {
	echo "error: sbsign not found (dnf install sbsigntools)" >&2
	exit 1
}
if [[ ! -r "$key" || ! -r "$crt" ]]; then
	echo "error: MOK key/cert not readable in $MOK_DIR (run as root?)" >&2
	exit 1
fi

rc=0
for img in "$@"; do
	if [[ ! -e "$img" ]]; then
		echo "warn: $img does not exist, skipping" >&2
		continue
	fi
	if sbverify --cert "$crt" "$img" >/dev/null 2>&1; then
		echo "$img: already signed by MOK, skipping"
		continue
	fi

	tmp="$(mktemp "${img}.sbsign.XXXXXX")"
	if sbsign --key "$key" --cert "$crt" --output "$tmp" "$img"; then
		# Copy the signed bytes back over the original so its inode,
		# permissions, owner and SELinux context are preserved.
		cp -f "$tmp" "$img"
		rm -f "$tmp"
		echo "$img: signed with MOK"
	else
		rm -f "$tmp"
		echo "$img: sbsign failed" >&2
		rc=1
	fi
done
exit $rc
