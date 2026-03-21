# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2011-2024 Entware

include $(TOPDIR)/rules.mk

ARCH:=arm
BOARD:=armv7-5.4
BOARDNAME:=Entware (armv7hf, Linux 5.4.61)
CPU_TYPE:=cortex-a7+neon-vfpv4
FEATURES:=gpio usb audio pci
KERNEL_PATCHVER:=5.4

include $(INCLUDE_DIR)/target.mk

define Target/Description
  Build Software Repository for ARMv7 hard-float devices on Linux 5.4, including Cortex-A7 NAS and embedded systems.
endef

$(eval $(call BuildTarget))
