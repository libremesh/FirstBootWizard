include $(TOPDIR)/rules.mk

PKG_NAME:=ubus-lime-fbw
PKG_VERSION=$(GIT_COMMIT_DATE)-$(GIT_COMMIT_TSTAMP)
GIT_COMMIT_DATE:=$(shell git log -n 1 --pretty=%ad --date=short . )
GIT_COMMIT_TSTAMP:=$(shell git log -n 1 --pretty=%at . )

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=ubus
  CATEGORY:=Ubus
  MAINTAINER:=Marcos Gutierrez <gmarcos87@gmail.com>
  SUBMENU:=3. Applications
  TITLE:=Libremesh first boot wizard ubus module
  DEPENDS:= +lua +libubox-lua +libubus-lua +libuci
  PKGARCH:=all
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) ./files/* $(1)/
	@chmod a+x $(1)/usr/libexec/daemon/lime-fbw
	@chmod a+x $(1)/etc/init.d/ubus-lime-fbw
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
