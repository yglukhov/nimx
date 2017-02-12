LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main

SDL_PATH := ../SDL

LOCAL_C_INCLUDES := $(LOCAL_PATH)/$(SDL_PATH)/include $(NIM_INCLUDE_DIR)

# Add your application source files here...
LOCAL_SRC_FILES :=  \
	$(patsubst $(LOCAL_PATH)/%, %, $(wildcard $(LOCAL_PATH)/*.cpp)) \
	$(patsubst $(LOCAL_PATH)/%, %, $(wildcard $(LOCAL_PATH)/*.c))

LOCAL_STATIC_LIBRARIES := $(STATIC_LIBRARIES) SDL2_static
LOCAL_SHARED_LIBRARIES :=

LOCAL_LDLIBS := -lGLESv1_CM -lGLESv2 -llog -landroid $(ADDITIONAL_LINKER_FLAGS)
LOCAL_CFLAGS := $(ADDITIONAL_COMPILER_FLAGS)

include $(BUILD_SHARED_LIBRARY)
