#!/bin/bash
#
# mok-add-to-kernel.sh - embed the MOK cert in this kernel's trusted keyring
#
# Sets CONFIG_SYSTEM_TRUSTED_KEYS to the MOK certificate so the builtin trusted
# keyring (and therefore the .secondary keyring used by the initramfs
# signature check, verify_pkcs7_signature(VERIFY_USE_SECONDARY_KEYRING)) trusts
# anything signed by the MOK - independent of Secure Boot / .machine keyring.
#
# Modules keep using the kernel's own build-time signing key (already embedded
# and trusted); the MOK is only for the initramfs here.  To also sign modules
# with the MOK, set MOK_SIGN_MODULES=1 (needs the private key readable at build
# time - see note below).
#
# Run from the kernel source tree (no root needed; reads only the public cert).
set -euo pipefail

MOK_DIR="${MOK_DIR:-/etc/pki/mok}"
crt="$MOK_DIR/MOK.crt"
pem="$MOK_DIR/MOK.pem"

if [[ ! -f scripts/config || ! -f Makefile ]]; then
	echo "error: run this from the kernel source tree" >&2
	exit 1
fi
if [[ ! -r "$crt" ]]; then
	echo "error: $crt not readable - run ./mok-gen.sh first" >&2
	exit 1
fi

./scripts/config --set-str SYSTEM_TRUSTED_KEYS "$crt"

if [[ "${MOK_SIGN_MODULES:-0}" == "1" ]]; then
	# NOTE: this makes the build read the MOK private key ($pem, 0600 root),
	# so you must build as root or loosen its permissions.  Usually not
	# needed - the default build key already signs & is trusted.
	if [[ ! -r "$pem" ]]; then
		echo "error: MOK_SIGN_MODULES=1 but $pem is not readable" >&2
		exit 1
	fi
	./scripts/config --set-str MODULE_SIG_KEY "$pem"
fi

make olddefconfig >/dev/null

echo "Updated .config:"
grep -E 'CONFIG_SYSTEM_TRUSTED_KEYS|CONFIG_MODULE_SIG_KEY' .config
echo
echo "Rebuild and install the kernel for the embedded cert to take effect:"
echo "  make -j\$(nproc) && sudo make modules_install install"
