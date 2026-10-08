TARGET := iphone:clang:latest:16.0
ARCHS := arm64
FINALPACKAGE := 1

# EliSpot Ubuntu/WSL build.
# All upstream source stays in this branch. Linux only skips the two source groups
# that require Apple's Swift/ActivityKit toolchain or libjamesdsp's Apple build.
SG_VERSION := $(or $(shell cat ../version.txt 2>/dev/null),0.0.0)
PACKAGE_VERSION := $(SG_VERSION)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := spotifyglass

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
spotifyglass_FILES := $(shell find Sources \( -name '*.m' -o -name '*.x' \) \
    ! -path 'Sources/Shared/JamesDSP/*' \
    ! -path 'Sources/Shared/LiveActivity/*' | sort)
# Upstream generates SGFlagList.m from a Spotify IPA. A deb-only build may not
# have that file; provide an empty table only when the real one is absent.
ifeq ($(wildcard Sources/Shared/Flags/SGFlagList.m),)
spotifyglass_FILES += UbuntuCompat/EmptyFlagList.m
endif
else
spotifyglass_FILES := $(shell find Sources -name '*.m' -o -name '*.x' -o -name '*.swift' | sort)
endif

spotifyglass_CFLAGS := -fobjc-arc -ISources -DSG_VERSION=\"$(SG_VERSION)\"
spotifyglass_FRAMEWORKS := UIKit QuartzCore UniformTypeIdentifiers MediaPlayer CoreImage AudioToolbox AVFoundation CoreHaptics
spotifyglass_LOGOS_DEFAULT_GENERATOR := internal

ifneq ($(UNAME_S),Linux)
SG_JDSP := ../vendor/libjamesdsp
spotifyglass_OBJ_FILES := $(SG_JDSP)/build/ios/libjamesdsp.a
Sources/Shared/JamesDSP/SGDSPEngine.m_CFLAGS := -isystem $(SG_JDSP)/subtree/Main/libjamesdsp/jni/jamesdsp/jdsp -isystem $(SG_JDSP)
endif

include $(THEOS_MAKE_PATH)/tweak.mk

ifneq ($(UNAME_S),Linux)
spotifyglass.all.tweak.variables: sg-libjamesdsp
.PHONY: sg-libjamesdsp
sg-libjamesdsp:
	@$(MAKE) --no-print-directory -C $(SG_JDSP) JDSP_PLATFORM=ios
endif

ifneq ($(UNAME_S),Linux)
before-all::
	@if [ -x ../scripts/check-layers.sh ]; then ../scripts/check-layers.sh Sources; fi
endif
