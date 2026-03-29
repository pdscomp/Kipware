#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-smart-open
PKG_VERSION:=7.5.1
PKG_RELEASE:=1

PYPI_NAME:=smart-open
PYPI_SOURCE_NAME:=smart_open
PKG_HASH:=3f08e16827c4733699e6b2cc40328a3568f900cb12ad9a3ad233ba6c872d9fe7

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-smart-open
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Utilities for streaming large files
  URL:=https://github.com/piskvorky/smart_open
  DEPENDS:=+python3-light +python3-wrapt
endef

define Package/python3-smart-open/description
  smart_open is a Python library for efficient streaming of very large
  files from/to local filesystem, S3, GCS, Azure Blob Storage, and
  other locations. This package installs core (local file) support only;
  cloud-storage extras require additional packages installed via pip.
endef

$(eval $(call Py3Package,python3-smart-open))
$(eval $(call BuildPackage,python3-smart-open))
$(eval $(call BuildPackage,python3-smart-open-src))
