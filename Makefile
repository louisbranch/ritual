.PHONY: run test build release

run:
	odin run src -out:ritual.bin -debug

build:
	odin build src -out:ritual.bin -debug

release:
	odin build src -out:ritual.bin -o:speed -disable-assert -no-bounds-check

test:
	odin test tests
