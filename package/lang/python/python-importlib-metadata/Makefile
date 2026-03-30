#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-importlib-metadata
PKG_VERSION:=8.7.1
PKG_RELEASE:=1

PYPI_NAME:=importlib-metadata
PYPI_SOURCE_NAME:=importlib_metadata
PKG_HASH:=49fef1ae6440c182052f407c8d34a68f72efc36db9ca90dc0113398f2fdde8bb

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-importlib-metadata
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Read metadata from Python packages
  URL:=https://github.com/python/importlib_metadata
  DEPENDS:=+python3-light +python3-zipp
endef

define Package/python3-importlib-metadata/description
  Read metadata from Python packages. Backport of importlib.metadata
  for Python 3.8+. Used by Moonraker.
endef

$(eval $(call Py3Package,python3-importlib-metadata))
$(eval $(call BuildPackage,python3-importlib-metadata))
$(eval $(call BuildPackage,python3-importlib-metadata-src))
