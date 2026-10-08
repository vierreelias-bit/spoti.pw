TARGET := iphone:clang:latest:16.0
ARCHS := arm64
FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := EliSpot
EliSpot_FILES := Sources/Tweak.x Sources/ELGlassTabBar.m Sources/ELRuntime.m Sources/ELMiniPlayer.m Sources/ELPlayerOverlay.m
EliSpot_CFLAGS := -fobjc-arc -ISources
EliSpot_FRAMEWORKS := UIKit QuartzCore MediaPlayer
EliSpot_LOGOS_DEFAULT_GENERATOR := internal

include $(THEOS_MAKE_PATH)/tweak.mk
