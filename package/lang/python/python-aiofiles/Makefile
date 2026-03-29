#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-aiofiles
PKG_VERSION:=25.1.0
PKG_RELEASE:=1

PYPI_NAME:=aiofiles
PKG_HASH:=a8d728f0a29de45dc521f18f07297428d56992a742f0cd2701ba86e44d23d5b2

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-aiofiles
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=File support for asyncio
  URL:=https://github.com/Tinche/aiofiles
  DEPENDS:=+python3-light
endef

define Package/python3-aiofiles/description
  aiofiles is a library for handling local disk files in asyncio
  applications. It provides non-blocking file operations by delegating
  work to a thread pool.
endef

$(eval $(call Py3Package,python3-aiofiles))
$(eval $(call BuildPackage,python3-aiofiles))
$(eval $(call BuildPackage,python3-aiofiles-src))
