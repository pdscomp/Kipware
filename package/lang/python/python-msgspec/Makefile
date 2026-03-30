#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-msgspec
PKG_VERSION:=0.19.0
PKG_RELEASE:=1

PYPI_NAME:=msgspec
PKG_HASH:=604037e7cd475345848116e89c553aa9a233259733ab51986ac924ab1b976f8e

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-msgspec
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Fast serialization and validation library
  URL:=https://jcristharif.com/msgspec/
  DEPENDS:=+python3-light
endef

define Package/python3-msgspec/description
  A fast serialization and validation library, with builtin support
  for JSON, MessagePack, YAML, and TOML. Used by Klipper webhooks.
endef

$(eval $(call Py3Package,python3-msgspec))
$(eval $(call BuildPackage,python3-msgspec))
$(eval $(call BuildPackage,python3-msgspec-src))
