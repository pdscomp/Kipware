#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-inotify-simple
PKG_VERSION:=2.0.1
PKG_RELEASE:=1

PYPI_NAME:=inotify-simple
PYPI_SOURCE_NAME:=inotify_simple
PKG_HASH:=f010bbbd8283bd71a9f4eb2de94765804ede24bd47320b0e6ef4136e541cdc2c

PKG_LICENSE:=BSD-2-Clause
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-inotify-simple
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Simple wrapper around inotify Linux kernel subsystem
  URL:=https://github.com/chrisjbillington/inotify_simple
  DEPENDS:=+python3-light
endef

define Package/python3-inotify-simple/description
  A simple wrapper around inotify. No fancy bells and whistles,
  just a literal wrapper with ctypes. Under 100 lines of code!
endef

$(eval $(call Py3Package,python3-inotify-simple))
$(eval $(call BuildPackage,python3-inotify-simple))
$(eval $(call BuildPackage,python3-inotify-simple-src))
