#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-preprocess-cancellation
PKG_VERSION:=0.2.1
PKG_RELEASE:=1

PYPI_NAME:=preprocess-cancellation
PYPI_SOURCE_NAME:=preprocess_cancellation
PKG_HASH:=e2f1224e1ba1603bdfdbf6937caaf91082dc849e5122e80a5328aa999433ce79

PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-preprocess-cancellation
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=G-code preprocessor for Klipper cancel objects
  URL:=https://github.com/kageurufu/cancelobject-preprocessor
  DEPENDS:=+python3-light
endef

define Package/python3-preprocess-cancellation/description
  GCode processor to add Klipper cancel-object markers.
  Allows selective cancellation of objects during a 3D print.
endef

$(eval $(call Py3Package,python3-preprocess-cancellation))
$(eval $(call BuildPackage,python3-preprocess-cancellation))
$(eval $(call BuildPackage,python3-preprocess-cancellation-src))
