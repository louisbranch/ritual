.PHONY: run test build release

BUILD_DIR := build
BIN := $(BUILD_DIR)/ritual

run:
	@mkdir -p $(BUILD_DIR)
	odin run src -out:$(BIN) -debug

build:
	@mkdir -p $(BUILD_DIR)
	odin build src -out:$(BIN) -debug

release:
	@mkdir -p $(BUILD_DIR)
	odin build src -out:$(BIN) -o:speed -disable-assert -no-bounds-check

test:
	odin test tests
