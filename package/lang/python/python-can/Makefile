#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-can
PKG_VERSION:=4.6.1
PKG_RELEASE:=1

PYPI_NAME:=python-can
PYPI_SOURCE_NAME:=python_can
PKG_HASH:=290fea135d04b8504ebff33889cc6d301e2181a54099116609f940825ffe5005

PKG_LICENSE:=LGPL-3.0
PKG_LICENSE_FILES:=LICENSE.txt

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-can
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Controller Area Network (CAN) interface library
  URL:=https://github.com/hardbyte/python-can
  DEPENDS:=+python3-light +python3-wrapt +python3-packaging +python3-typing-extensions
endef

define Package/python3-can/description
  Controller Area Network interface module for Python.
  Provides support for CAN bus communication used by Klipper for
  MCU connections.
endef

$(eval $(call Py3Package,python3-can))
$(eval $(call BuildPackage,python3-can))
$(eval $(call BuildPackage,python3-can-src))
