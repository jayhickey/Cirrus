PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max
PLATFORM_MACOS = macOS

default: test-all

test-all: test-swift build-example

test-swift:
	swift test \
		--enable-pubgrub-resolver \
		--enable-test-discovery \
		--parallel

build-example:
	xcodebuild \
		-project Example/CirrusExample.xcodeproj
		-scheme CirrusExample \
		-destination platform="$(PLATFORM_IOS)"

	xcodebuild \
		-project Example/CirrusExample.xcodeproj
		-scheme CirrusExample \
		-destination platform="$(PLATFORM_MACOS)"

format:
	swift format --in-place --recursive ./Package.swift ./Sources ./Tests ./Example

.PHONY: format test-all test-swift build-example