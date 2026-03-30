#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-certifi
PKG_VERSION:=2025.1.31
PKG_RELEASE:=1

PYPI_NAME:=certifi
PKG_HASH:=3d5da6925056f6f18f119200434a4780a94263f10d1c21d032a6f6b2baa20651

PKG_LICENSE:=MPL-2.0
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-certifi
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Mozilla\'s CA Bundle for SSL/TLS validation
  URL:=https://github.com/certifi/python-certifi
  DEPENDS:=+python3-light
endef

define Package/python3-certifi/description
  Python package for providing Mozilla's CA Bundle.
  Provides SSL/TLS certificate validation for HTTP requests.
  Required by apprise.
endef

$(eval $(call Py3Package,python3-certifi))
$(eval $(call BuildPackage,python3-certifi))
$(eval $(call BuildPackage,python3-certifi-src))
