#!/bin/sh

set -eu

REPO="https://kipware.emulate.us/armv7hf-k5.4"

echo "Checking CPU ABI compatibility..."
if grep -Eiq 'neon|vfpv4' /proc/cpuinfo 2>/dev/null; then
	echo "  VFPv4/NEON confirmed."
else
	echo "  Warning: VFPv4/NEON not found in /proc/cpuinfo."
	echo "  This port expects an ARMv7 hard-float CPU with NEON/VFPv4 support."
fi

echo "Checking kernel version..."
KVER=$(uname -r)
KMAJ=${KVER%%.*}
REST=${KVER#*.}
KMIN=${REST%%.*}

if [ "$KMAJ" -lt 5 ] || { [ "$KMAJ" -eq 5 ] && [ "$KMIN" -lt 4 ]; }; then
	echo "  Kernel $KVER is below 5.4. This port requires kernel >= 5.4."
	exit 1
fi

echo "  Kernel $KVER OK."

wget -O - "${REPO}/installer/generic.sh" | sh
