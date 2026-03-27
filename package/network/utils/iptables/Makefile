#
# Copyright (C) 2006-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Entware specific: keep 1.4.21 version
# Do not split extensions into separate packages, do not install dev headers

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=iptables
PKG_VERSION:=1.4.21

ifndef CONFIG_PACKAGE_opt-ndmsv2
  PKG_RELEASE:=5
else
  PKG_RELEASE:=6
endif

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://www.netfilter.org/projects/iptables/files \
	ftp://ftp.be.netfilter.org/pub/netfilter/iptables/ \
	ftp://ftp.de.netfilter.org/pub/netfilter/iptables/ \
	ftp://ftp.no.netfilter.org/pub/netfilter/iptables/
PKG_HASH:=52004c68021da9a599feed27f65defcfb22128f7da2c0531c0f75de0f479d3e0

PKG_FIXUP:=autoreconf

PKG_INSTALL:=1
PKG_BUILD_FLAGS:=gc-sections no-lto
PKG_BUILD_PARALLEL:=1
PKG_LICENSE:=GPL-2.0
PKG_CPE_ID:=cpe:/a:netfilter:iptables

ifdef CONFIG_PACKAGE_opt-ndmsv2
PATCH_DIR:=./patches_kn
endif

include $(INCLUDE_DIR)/package.mk

define Package/iptables
  TITLE:=IP firewall administration tool
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Firewall
  URL:=https://netfilter.org/
  ALTERNATIVES:=\
    200:$(ENTWARE_PREFIX)/bin/iptables-xml:$(ENTWARE_PREFIX)/sbin/xtables-multi \
    200:$(ENTWARE_PREFIX)/sbin/iptables:$(ENTWARE_PREFIX)/sbin/xtables-multi \
    200:$(ENTWARE_PREFIX)/sbin/iptables-restore:$(ENTWARE_PREFIX)/sbin/xtables-multi \
    200:$(ENTWARE_PREFIX)/sbin/iptables-save:$(ENTWARE_PREFIX)/sbin/xtables-multi \
    200:$(ENTWARE_PREFIX)/sbin/ip6tables:$(ENTWARE_PREFIX)/sbin/xtables-multi \
    200:$(ENTWARE_PREFIX)/sbin/ip6tables-restore:$(ENTWARE_PREFIX)/sbin/xtables-multi \
    200:$(ENTWARE_PREFIX)/sbin/ip6tables-save:$(ENTWARE_PREFIX)/sbin/xtables-multi
ifdef CONFIG_PACKAGE_opt-ndmsv2
  PKGARCH:=$(BOARD)_kn
endif
endef

define Package/iptables/description
IP firewall administration tool.

 Matches:
  - icmp
  - tcp
  - udp
  - comment
  - conntrack
  - limit
  - mac
  - mark
  - multiport
  - set
  - state
  - time

 Targets:
  - ACCEPT
  - CT
  - DNAT
  - DROP
  - REJECT
  - LOG
  - MARK
  - MASQUERADE
  - REDIRECT
  - SET
  - SNAT
  - TCPMSS

 Tables:
  - filter
  - mangle
  - nat
  - raw

endef

TARGET_CPPFLAGS := \
	-I$(PKG_BUILD_DIR)/include \
	-I$(LINUX_DIR)/user_headers/include \
	$(TARGET_CPPFLAGS)

TARGET_CFLAGS += \
	-I$(PKG_BUILD_DIR)/include \
	-I$(LINUX_DIR)/user_headers/include \
	-DNO_LEGACY

TARGET_LDFLAGS += -lm

CONFIGURE_ARGS += \
	--enable-shared \
	--enable-static \
	--enable-devel \
	--with-kernel="$(LINUX_DIR)/user_headers" \
	--with-xtlibdir=$(ENTWARE_PREFIX)/lib/iptables \
	$(if $(CONFIG_IPV6),,--disable-ipv6)

MAKE_FLAGS := \
	$(TARGET_CONFIGURE_OPTS) \
	COPT_FLAGS="$(TARGET_CFLAGS)" \
	KERNEL_DIR="$(LINUX_DIR)/user_headers/" PREFIX=$(ENTWARE_PREFIX) \
	KBUILD_OUTPUT="$(LINUX_DIR)"

ifndef CONFIG_PACKAGE_opt-ndmsv2
  define Build/InstallDev
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/include
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/include/iptables
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/include/net/netfilter

	# XXX: iptables header fixup, some headers are not installed by iptables anymore
	$(CP) $(PKG_BUILD_DIR)/include/iptables/*.h $(1)$(ENTWARE_PREFIX)/include/iptables/
	$(CP) $(PKG_BUILD_DIR)/include/iptables.h $(1)$(ENTWARE_PREFIX)/include/
	$(CP) $(PKG_BUILD_DIR)/include/ip6tables.h $(1)$(ENTWARE_PREFIX)/include/
	$(CP) $(PKG_BUILD_DIR)/include/libipulog $(1)$(ENTWARE_PREFIX)/include/
	$(CP) $(PKG_BUILD_DIR)/include/libiptc $(1)$(ENTWARE_PREFIX)/include/

	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/include/* $(1)$(ENTWARE_PREFIX)/include/
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libxtables.so* $(1)$(ENTWARE_PREFIX)/lib/
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libip*tc.so* $(1)$(ENTWARE_PREFIX)/lib/
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib/pkgconfig
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/pkgconfig/xtables.pc $(1)$(ENTWARE_PREFIX)/lib/pkgconfig/
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/pkgconfig/libip*tc.pc $(1)$(ENTWARE_PREFIX)/lib/pkgconfig/

	# XXX: needed by firewall3
	$(CP) $(PKG_BUILD_DIR)/extensions/libiptext*.so $(1)$(ENTWARE_PREFIX)/lib/
  endef
endif

define Package/iptables/install
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/sbin
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/sbin/xtables-multi $(1)$(ENTWARE_PREFIX)/sbin/
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libip*tc.so* $(1)$(ENTWARE_PREFIX)/lib/
	$(CP) $(PKG_BUILD_DIR)/extensions/libiptext{,4,6}.so $(1)$(ENTWARE_PREFIX)/lib/
	$(CP) $(PKG_INSTALL_DIR)$(ENTWARE_PREFIX)/lib/libxtables.so* $(1)$(ENTWARE_PREFIX)/lib/
	$(INSTALL_DIR) $(1)$(ENTWARE_PREFIX)/lib/iptables
	$(CP) $(PKG_BUILD_DIR)/extensions/libxt_*.so $(1)$(ENTWARE_PREFIX)/lib/iptables/
endef

$(eval $(call BuildPackage,iptables))
