XCODEGEN ?= xcodegen

.PHONY: help project test build lint clean

help:
	@echo "project  Generate SwipeShrinkExample.xcodeproj from project.yml"
	@echo "build    Build every SwiftPM target, including the test targets"
	@echo "test     Run the unit tests"
	@echo "clean    Remove build artefacts and the generated project"

# The example project is generated, not checked in, so this is the first thing
# to run after cloning.
project:
	@command -v $(XCODEGEN) >/dev/null 2>&1 || { \
		echo "xcodegen not found. Install it with: brew install xcodegen"; \
		exit 1; \
	}
	cd SwipeShrinkExample && $(XCODEGEN) generate

build:
	swift build --build-tests

test:
	swift test

clean:
	swift package clean
	rm -rf .build SwipeShrinkExample/SwipeShrinkExample.xcodeproj
