#!/bin/bash
#
# mok-gen.sh - generate a Machine Owner Key (MOK)
#
# Creates an RSA key + self-signed X.509 cert used to:
#   - sign the initramfs (see mok-sign-initramfs.sh / the kernel-install hook)
#   - optionally sign the kernel image (sbsign) once you enroll it via shim
#
# The key MUST be stable: regenerating it means re-enrolling (a reboot).  So
# this script refuses to clobber an existing key.
#
# Files (in $MOK_DIR, default /etc/pki/mok):
#   MOK.key  private key           (0600 root - only the signing hook reads it)
#   MOK.crt  PEM certificate       (0644 - embedded in the kernel keyring)
#   MOK.der  DER certificate       (0644 - for mokutil / mok-enroll.sh)
#   MOK.pem  key+cert              (0600 - only if you want MOK module signing)
#
# Run as root (writes under /etc).
set -euo pipefail

MOK_DIR="${MOK_DIR:-/etc/pki/mok}"
MOK_CN="${MOK_CN:-$(hostname -s) kernel signing key}"
MOK_DAYS="${MOK_DAYS:-3650}"
MOK_BITS="${MOK_BITS:-2048}"

key="$MOK_DIR/MOK.key"
crt="$MOK_DIR/MOK.crt"
der="$MOK_DIR/MOK.der"
pem="$MOK_DIR/MOK.pem"

if [[ $EUID -ne 0 ]]; then
	echo "error: run as root (writes $MOK_DIR)" >&2
	exit 1
fi

if [[ -e "$key" ]]; then
	echo "error: $key already exists - refusing to overwrite." >&2
	echo "       Regenerating would require re-enrolling the MOK." >&2
	echo "       Remove $MOK_DIR by hand if you really mean to." >&2
	exit 1
fi

install -d -m 0755 "$MOK_DIR"

openssl req -new -x509 -utf8 -sha256 -batch -nodes \
	-days "$MOK_DAYS" -newkey "rsa:$MOK_BITS" \
	-keyout "$key" -out "$crt" \
	-subj "/CN=$MOK_CN/" \
	-addext "basicConstraints=critical,CA:FALSE" \
	-addext "keyUsage=critical,digitalSignature" \
	-addext "extendedKeyUsage=codeSigning"

openssl x509 -in "$crt" -outform DER -out "$der"
cat "$key" "$crt" > "$pem"

chmod 0600 "$key" "$pem"
chmod 0644 "$crt" "$der"

echo "Generated MOK in $MOK_DIR:"
printf '  %s\n' "$key" "$crt" "$der" "$pem"
echo
echo "Next:"
echo "  sudo ./mok-enroll.sh        # enroll in UEFI (then reboot to confirm)"
echo "  ./mok-add-to-kernel.sh      # embed the cert in this kernel build"
