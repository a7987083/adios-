SDK ?= iphoneos
ARCH ?= arm64
MIN_IOS ?= 12.0
PRODUCT := RewardTrace.dylib
BUILD_DIR := build
SRC := src/RewardTrace.mm
INCLUDES := -Iinclude
SDKROOT := $(shell xcrun --sdk $(SDK) --show-sdk-path)
CXX := xcrun --sdk $(SDK) clang++
CXXFLAGS := -target $(ARCH)-apple-ios$(MIN_IOS) -arch $(ARCH) -isysroot $(SDKROOT) \
	-std=c++17 -fvisibility=hidden -fno-exceptions -fno-rtti -Wall -Wextra -Werror \
	-Wno-unused-parameter $(INCLUDES)
LDFLAGS := -dynamiclib -Wl,-install_name,@rpath/$(PRODUCT) -Wl,-dead_strip
.PHONY: all clean verify check
all: check $(BUILD_DIR)/$(PRODUCT)
check:
	python3 scripts/check_offsets.py
$(BUILD_DIR)/$(PRODUCT): $(SRC) include/RewardTraceOffsets.h
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(SRC) $(LDFLAGS) -o $@
	codesign --force --sign - $@
verify: all
	file $(BUILD_DIR)/$(PRODUCT)
	lipo -info $(BUILD_DIR)/$(PRODUCT)
	otool -hv $(BUILD_DIR)/$(PRODUCT)
	otool -L $(BUILD_DIR)/$(PRODUCT)
	codesign -dv --verbose=2 $(BUILD_DIR)/$(PRODUCT) 2>&1
	shasum -a 256 $(BUILD_DIR)/$(PRODUCT)
clean:
	rm -rf $(BUILD_DIR)
