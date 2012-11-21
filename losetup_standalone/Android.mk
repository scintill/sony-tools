LOCAL_PATH := $(call my-dir)

ifneq ($(TARGET_SIMULATOR),true)
ifeq ($(TARGET_ARCH),arm)

include $(CLEAR_VARS)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := losetup.c
LOCAL_MODULE := losetup-static
LOCAL_MODULE_TAGS := optional
LOCAL_FORCE_STATIC_EXECUTABLE := true
LOCAL_STATIC_LIBRARIES =  libc
include $(BUILD_EXECUTABLE)


endif	# TARGET_ARCH == arm
endif	# !TARGET_SIMULATOR
