#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-wrapt
PKG_VERSION:=2.1.2
PKG_RELEASE:=1

PYPI_NAME:=wrapt
PKG_HASH:=3996a67eecc2c68fd47b4e3c564405a5777367adfd9b8abb58387b63ee83b21e

PKG_LICENSE:=BSD-2-Clause
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-wrapt
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Decorators, wrappers and monkey patching
  URL:=https://github.com/GrahamDumpleton/wrapt
  DEPENDS:=+python3-light
endef

define Package/python3-wrapt/description
  A Python module for decorating functions, methods and objects,
  providing better introspection support and consistent behaviour
  between different decoration patterns.
endef

# Build pure-Python variant to avoid C-extension cross-compilation complexity.
# The pure-Python implementation is fully functional; the C extension is
# a performance optimisation only.
PYTHON3_PKG_BUILD_VARS:=WRAPT_DISABLE_EXTENSIONS=True

$(eval $(call Py3Package,python3-wrapt))
$(eval $(call BuildPackage,python3-wrapt))
$(eval $(call BuildPackage,python3-wrapt-src))
