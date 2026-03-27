#
# Copyright (C) 2006-2013 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Entware specific: add ALTERNATIVES ar

include $(TOPDIR)/rules.mk

PKG_NAME:=binutils
PKG_VERSION:=2.45.1
PKG_RELEASE:=1

PKG_SOURCE_URL:=@GNU/binutils
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
# XXX is it twice?
#PKG_VERSION:=$(PKG_VERSION)
PKG_HASH:=5fe101e6fe9d18fdec95962d81ed670fdee5f37e3f48f0bef87bddf862513aa5

PKG_FIXUP:=patch-libtool
PKG_LIBTOOL_PATHS:=. gas bfd opcodes gprof gprofng binutils ld libiberty gold intl libctf libsframe
PKG_REMOVE_FILES:=libtool.m4
PKG_INSTALL:=1

PKG_MAINTAINER:=Felix Fietkau <nbd@nbd.name>
PKG_LICENSE:=GPL-3.0+
PKG_CPE_ID:=cpe:/a:gnu:binutils
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

include $(INCLUDE_DIR)/nls.mk
include $(INCLUDE_DIR)/package.mk

define Package/libbfd
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libbfd
  DEPENDS:=+zlib $(INTL_DEPENDS)
endef

define Package/libctf
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libctf
  DEPENDS:=+libbfd
endef

define Package/libopcodes
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libopcodes
  DEPENDS:=+libbfd
endef

define Package/binutils
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=binutils
  DEPENDS:=+objdump +ar
  ALTERNATIVES:=200:$(ENTWARE_PREFIX)/bin/strings:$(ENTWARE_PREFIX)/bin/binutils-strings
endef

define Package/objdump
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=objdump
  DEPENDS:=+libopcodes +libctf
endef

define Package/ar
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=ar
  DEPENDS:=+zlib +libbfd
  ALTERNATIVES:=200:$(ENTWARE_PREFIX)/bin/ar:$(ENTWARE_PREFIX)/bin/binutils-ar
endef

define Package/binutils/description
  The Binutils package contains a linker, an assembler, and other tools for handling object files
endef

TARGET_CFLAGS += $(FPIC) -Wno-unused-value

TARGET_LDFLAGS += $(if $(INTL_FULL),-lintl)

GCC_VERSION:=$(call qstrip,$(CONFIG_GCC_VERSION))

CONFIGURE_ARGS += \
	--host=$(REAL_GNU_TARGET_NAME) \
	--target=$(REAL_GNU_TARGET_NAME) \
	--enable-shared \
	--enable-install-libiberty \
	--enable-install-libbfd \
	--enable-install-libctf \
	--with-lib-path="$(ENTWARE_PREFIX)/lib/gcc/$(REAL_GNU_TARGET_NAME)/$(GCC_VERSION):$(ENTWARE_PREFIX)/lib:$(ENTWARE_PREFIX)/usr/lib" \
	--with-system-zlib \
	--without-zstd \
	--without-msgpack \
	--disable-gprofng

define Build/Install
	$(call Build/Install/Default)
	$(MAKE) -C $(PKG_BUILD_DIR)/libiberty \
		target_header_dir=libiberty \
		DESTDIR="$(PKG_INSTALL_DIR)" \
		MULTIOSDIR="" \
		install
endef

define Build/InstallDev
	$(CP) $(PKG_INSTALL_DIR)/* $(1)/
endef

define Package/libbfd/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libbfd*.so* $(1)$(ENTWARE_PREFIX)/lib/
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libsframe*.so* $(1)$(ENTWARE_PREFIX)/lib/
endef

define Package/libctf/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libctf*.so* $(1)$(ENTWARE_PREFIX)/lib/
endef

define Package/libopcodes/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libopcodes*.so $(1)$(ENTWARE_PREFIX)/lib/
endef

define Package/objdump/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/bin
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/objdump $(1)$(ENTWARE_PREFIX)/bin/
endef

define Package/ar/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/bin
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/ar $(1)$(ENTWARE_PREFIX)/bin/binutils-ar
endef

define Package/binutils/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/bin/ $(1)$(ENTWARE_PREFIX)/
	mv $(1)$(ENTWARE_PREFIX)/bin/strings $(1)$(ENTWARE_PREFIX)/bin/binutils-strings
	rm -f $(1)$(ENTWARE_PREFIX)/bin/objdump
	rm -f $(1)$(ENTWARE_PREFIX)/bin/ar
endef

$(eval $(call BuildPackage,libbfd))
$(eval $(call BuildPackage,libctf))
$(eval $(call BuildPackage,libopcodes))
$(eval $(call BuildPackage,binutils))
$(eval $(call BuildPackage,objdump))
$(eval $(call BuildPackage,ar))
