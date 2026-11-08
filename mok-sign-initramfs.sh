#!/bin/bash
#
# mok-sign-initramfs.sh - append a MOK signature to an initramfs image
#
# Produces the layout the kernel's CONFIG_INITRAMFS_SIG check expects:
#   [ cpio payload ][ PKCS#7 sig ][ struct module_signature ][ marker ]
# where marker == "~initrd signature appended~\n".  Uses scripts/sign-file -i.
#
# Usage: mok-sign-initramfs.sh <initramfs-image> [<initramfs-image> ...]
#
# Env:
#   MOK_DIR    default /etc/pki/mok          (expects MOK.key, MOK.crt)
#   MOK_HASH   default sha512                (match CONFIG_MODULE_SIG_HASH)
#   SIGN_FILE  path to sign-file (autodetected if unset)
#
# Must run as root (reads the 0600 MOK key, writes /boot).  Idempotent: skips
# an image that is already signed.
set -euo pipefail

MOK_DIR="${MOK_DIR:-/etc/pki/mok}"
MOK_HASH="${MOK_HASH:-sha512}"
key="$MOK_DIR/MOK.key"
crt="$MOK_DIR/MOK.crt"
marker='~initrd signature appended~'

if [[ $# -lt 1 ]]; then
	echo "usage: $0 <initramfs-image> [...]" >&2
	exit 2
fi

# Locate sign-file.
if [[ -z "${SIGN_FILE:-}" ]]; then
	for c in \
		"/usr/local/sbin/sign-file" \
		"$(dirname "$(readlink -f "$0")")/scripts/sign-file" \
		"./scripts/sign-file" \
		"/lib/modules/$(uname -r)/build/scripts/sign-file" \
		"/usr/src/kernels/$(uname -r)/scripts/sign-file"; do
		[[ -x "$c" ]] && { SIGN_FILE="$c"; break; }
	done
fi
if [[ -z "${SIGN_FILE:-}" || ! -x "$SIGN_FILE" ]]; then
	echo "error: sign-file not found; set SIGN_FILE=<path to scripts/sign-file>" >&2
	exit 1
fi
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
	if tail -c 64 "$img" | grep -aq "$marker"; then
		echo "$img: already signed, skipping"
		continue
	fi
	"$SIGN_FILE" -i "$MOK_HASH" "$key" "$crt" "$img" || { rc=1; continue; }
	echo "$img: signed with MOK ($MOK_HASH)"
done
exit $rc
