#
# Copyright (C) 2025 Kipware
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-streaming-form-data
PKG_VERSION:=2.0.0
PKG_RELEASE:=1

PYPI_NAME:=streaming-form-data
PYPI_SOURCE_NAME:=streaming_form_data
PKG_HASH:=cab18e7b5d31e79ac6ec71a5f2e880aafdd90321bd2197955fd7fdbd7f3e2101

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

# Cython is needed if the sdist does not contain pre-generated .c files.
# If the build fails with "Cython not found", uncomment the line below.
# PKG_BUILD_DEPENDS:=python3/host python-setuptools/host python-wheel/host python-cython/host

PYTHON3_PKG_HELPER_DIR:=$(TOPDIR)/feeds/packages/lang/python

include $(PYTHON3_PKG_HELPER_DIR)/pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(PYTHON3_PKG_HELPER_DIR)/python3-package.mk

define Package/python3-streaming-form-data
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Streaming parser for multipart/form-data
  URL:=https://github.com/siddhantgoel/streaming-form-data
  DEPENDS:=+python3-light +python3-smart-open +python3-aiofiles
endef

define Package/python3-streaming-form-data/description
  streaming-form-data provides a streaming parser for
  multipart/form-data encoded data, which is the encoding used by HTML
  forms with file uploads. It is useful for parsing large uploads
  without buffering the entire request in memory.
endef

$(eval $(call Py3Package,python3-streaming-form-data))
$(eval $(call BuildPackage,python3-streaming-form-data))
$(eval $(call BuildPackage,python3-streaming-form-data-src))
