#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-requests-oauthlib
PKG_VERSION:=2.0.0
PKG_RELEASE:=1

PYPI_NAME:=requests-oauthlib
PKG_HASH:=b3dffaebd884d8cd778494369603a9e7b58d29111bf6b41bdc2dcd87203af4e9

PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-requests-oauthlib
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=OAuthlib authentication support for Requests
  URL:=https://github.com/requests/requests-oauthlib
  DEPENDS:=+python3-light +python3-requests
endef

define Package/python3-requests-oauthlib/description
  OAuthlib authentication support for Requests.
  Provides OAuth 1.0 and 2.0 support for the Python Requests library.
  Required by apprise.
endef

$(eval $(call Py3Package,python3-requests-oauthlib))
$(eval $(call BuildPackage,python3-requests-oauthlib))
$(eval $(call BuildPackage,python3-requests-oauthlib-src))
