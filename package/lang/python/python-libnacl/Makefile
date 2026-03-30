#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-libnacl
PKG_VERSION:=2.1.0
PKG_RELEASE:=1

PYPI_NAME:=libnacl
PKG_HASH:=f3418da7df29e6d9b11fd7d990289d16397dc1020e4e35192e11aee826922860

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-libnacl
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Python bindings for libsodium (NaCl)
  URL:=https://libnacl.readthedocs.org
  DEPENDS:=+python3-light +libsodium
endef

define Package/python3-libnacl/description
  Python bindings for libsodium/tweetnacl based on ctypes.
  Provides cryptographic operations like encryption, decryption,
  signing, and hashing.
endef

$(eval $(call Py3Package,python3-libnacl))
$(eval $(call BuildPackage,python3-libnacl))
$(eval $(call BuildPackage,python3-libnacl-src))
