# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2016-2019 Yousong Zhou <yszhou4tech@gmail.com>

include $(TOPDIR)/rules.mk

PKG_NAME:=dtc
PKG_VERSION:=1.7.2
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_HASH:=f200e5ebd7afd20d4b3804a3085af0870fcf3c194f8d7f0f6985cf8bbb4ac0f4
PKG_SOURCE_URL:=@KERNEL/software/utils/dtc

PKG_MAINTAINER:=Yousong Zhou <yszhou4tech@gmail.com>
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=GPL
PKG_CPE_ID:=cpe:/a:dtc_project:dtc

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/meson.mk

define Package/dtc
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Device Tree Compiler
  URL:=https://git.kernel.org/pub/scm/utils/dtc/dtc.git
endef

define Package/dtc/description
  Device Tree Compiler for Flat Device Trees Device Tree Compiler, dtc, takes
  as input a device-tree in a given format and outputs a device-tree in another
  format for booting kernels on embedded systems.
endef

define Package/dtc/config
	config DTC_STATIC_BUILD
		depends on PACKAGE_dtc
		bool "Build dtc as static binary"
		default n
		help
			Builds dtc as a static binary.
			This is usefull in order to export live DTS from a device running
			various vendor modified OpenWrt versions.
endef

define Package/dtc/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/bin
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/dtc $(1)$(ENTWARE_PREFIX)/bin
endef


# See Documentation/manual.txt for details about each utility
define Package/fdt-utils
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Flat Device Tree Utilities
  URL:=https://git.kernel.org/pub/scm/utils/dtc/dtc.git
  DEPENDS:=+libfdt
endef

define Package/fdt-utils/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/convert-dtsv0 $(1)$(ENTWARE_PREFIX)/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/fdtdump $(1)$(ENTWARE_PREFIX)/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/fdtget $(1)$(ENTWARE_PREFIX)/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/fdtput $(1)$(ENTWARE_PREFIX)/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/fdtoverlay $(1)$(ENTWARE_PREFIX)/bin
endef


define Package/libfdt
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=a utility library for reading and manipulating dtb files
  URL:=https://git.kernel.org/pub/scm/utils/dtc/dtc.git
endef

define Package/libfdt/description
  This is a library containing functions for manipulating Flat Device Trees.
endef

define Package/libfdt/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libfdt*.so* $(1)$(ENTWARE_PREFIX)/lib
endef

MESON_ARGS += \
	-Dtests=false \
	-Dtools=true \
	-Dyaml=disabled \
	-Dvalgrind=disabled \
	-Dpython=disabled \
	-Dstatic-build=$(if $(CONFIG_DTC_STATIC_BUILD),true,false)

define Build/InstallDev
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/include
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/include/* $(1)$(ENTWARE_PREFIX)/include
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/* $(1)$(ENTWARE_PREFIX)/lib
endef

$(eval $(call BuildPackage,dtc))
$(eval $(call BuildPackage,fdt-utils))
$(eval $(call BuildPackage,libfdt))
