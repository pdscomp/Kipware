#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-apprise
PKG_VERSION:=1.9.8
PKG_RELEASE:=1

PYPI_NAME:=apprise
PKG_HASH:=2e06f9ebad47e67f3f184bb789a7966bec3261a53556c90acb1b1cdb85d84a2c

PKG_LICENSE:=BSD-2-Clause
PKG_LICENSE_FILES:=LICENSE

# FIX: Add babel as build dependency (needed for i18n localization support)
PKG_BUILD_DEPENDS:=python-babel/host

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-apprise
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Push Notifications to all major platforms
  URL:=https://appriseit.com
  DEPENDS:=+python3-light +python3-requests +python3-requests-oauthlib +python3-click +python3-markdown +python3-yaml +python3-certifi
endef

define Package/python3-apprise/description
  Push Notifications that work with just about every platform!
  Used by Moonraker for printer status notifications.
endef

$(eval $(call Py3Package,python3-apprise))
$(eval $(call BuildPackage,python3-apprise))
$(eval $(call BuildPackage,python3-apprise-src))
