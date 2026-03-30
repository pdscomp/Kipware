#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-ldap3
PKG_VERSION:=2.9.1
PKG_RELEASE:=1

PYPI_NAME:=ldap3
PKG_HASH:=f3e7fc4718e3f09dda568b57100095e0ce58633bcabbed8667ce3f8fbaa4229f

PKG_LICENSE:=LGPL-3.0
PKG_LICENSE_FILES:=LICENSE.txt COPYING.txt COPYING.LESSER.txt

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-ldap3
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=RFC 4510 conforming LDAP V3 pure Python client
  URL:=https://github.com/cannatag/ldap3
  DEPENDS:=+python3-light +python3-pyasn1
endef

define Package/python3-ldap3/description
  A strictly RFC 4510 conforming LDAP V3 pure Python client library.
  Supports both standard and secure (LDAPS) connections.
endef

$(eval $(call Py3Package,python3-ldap3))
$(eval $(call BuildPackage,python3-ldap3))
$(eval $(call BuildPackage,python3-ldap3-src))
