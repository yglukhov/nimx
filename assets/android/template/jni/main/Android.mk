LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := main_static
LOCAL_SRC_FILES := $(TARGET_ARCH_ABI)/libmain_static.a
include $(PREBUILT_STATIC_LIBRARY)
