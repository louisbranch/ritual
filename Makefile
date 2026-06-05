.PHONY: run test build

run:
	odin run src -out:ritual.bin

build:
	odin build src -out:ritual.bin

test:
	odin test tests
