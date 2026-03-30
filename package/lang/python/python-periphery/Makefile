#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-periphery
PKG_VERSION:=2.4.1
PKG_RELEASE:=1

PYPI_NAME:=python-periphery
PKG_HASH:=61d461d736982a6f766e878720ab10a68151e2e8c1086600d9389ac47e40e88a

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-periphery
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Python peripheral I/O library (GPIO, SPI, I2C, MMIO, UART)
  URL:=https://github.com/vsergeev/python-periphery
  DEPENDS:=+python3-light
endef

define Package/python3-periphery/description
  A pure Python 2/3 library for peripheral I/O (GPIO, LED, PWM, SPI,
  I2C, MMIO, Serial) in Linux. Useful for 3D printer board communication.
endef

$(eval $(call Py3Package,python3-periphery))
$(eval $(call BuildPackage,python3-periphery))
$(eval $(call BuildPackage,python3-periphery-src))
