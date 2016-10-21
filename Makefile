ARCHS := arm64
TARGET := iphone:clang:9.2:9.3

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Temporaryleave
Temporaryleave_FILES = Tweak.xm
Temporaryleave_FRAMEWORKS = UIKit Foundation
Temporaryleave_LIBRARIES = applist
Temporaryleave_PRIVATEFRAMEWORKS = CoreBrightness

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard; rm /User/Library/Preferences/xyz.gsora.temporaryleavesettings.plist"
SUBPROJECTS += temporaryleavesettings
include $(THEOS_MAKE_PATH)/aggregate.mk
