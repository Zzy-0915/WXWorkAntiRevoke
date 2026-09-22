TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES := WXWork
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WXWorkAntiRevoke
WXWorkAntiRevoke_FILES = Tweak.xm
WXWorkAntiRevoke_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
WXWorkAntiRevoke_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKEFILE_PATH)/tweak.mk
