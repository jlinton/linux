#!/bin/bash
#
# mok-enroll.sh - enroll the MOK into the UEFI MOK store via shim
#
# mokutil queues the cert for enrollment and asks for a one-time password.
# After this you MUST reboot: shim's blue "MOK management" screen will ask you
# to confirm the enrollment with that password.
#
# Enrolling puts the key in the UEFI MokList, which:
#   - lets shim trust a kernel image you sign with it (sbsign), and
#   - with CONFIG_INTEGRITY_MACHINE_KEYRING + CONFIG_LOAD_UEFI_KEYS, loads it
#     into the kernel .machine keyring at boot (another path to trust the
#     signed initramfs/modules, in addition to the embedded cert).
#
# Run as root.
set -euo pipefail

MOK_DIR="${MOK_DIR:-/etc/pki/mok}"
der="$MOK_DIR/MOK.der"

if [[ $EUID -ne 0 ]]; then
	echo "error: run as root (mokutil writes a UEFI variable)" >&2
	exit 1
fi

if [[ ! -e "$der" ]]; then
	echo "error: $der not found - run ./mok-gen.sh first" >&2
	exit 1
fi

if mokutil --test-key "$der" 2>/dev/null | grep -q "already enrolled"; then
	echo "MOK already enrolled - nothing to do."
	exit 0
fi

echo "Importing $der.  You'll be prompted for a one-time enrollment password."
mokutil --import "$der"

cat <<EOF

Queued for enrollment.  Now:
  1. Reboot.
  2. At the blue "Shim UEFI key management" screen: Enroll MOK -> Continue
     -> Yes, and enter the password you just set.
  3. Verify after boot:   mokutil --test-key $der
EOF
