LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main

LOCAL_SRC_FILES := $(patsubst $(LOCAL_PATH)/%, %, $(wildcard $(LOCAL_PATH)/src/*.cpp)) \
$(patsubst $(LOCAL_PATH)/%, %, $(wildcard $(LOCAL_PATH)/src/*.c))

LOCAL_STATIC_LIBRARIES := SDL2_static

include $(BUILD_SHARED_LIBRARY)
$(call import-module,SDL)LOCAL_PATH := $(call my-dir)
