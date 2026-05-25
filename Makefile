GODOT ?= godot
GDLINT ?= gdlint
EXPORT_DIR ?= export
EXPORT_PRESET ?= Linux/X11

.PHONY: all build run test lint clean export

all: lint test build

build:
	$(GODOT) --headless --export-release "$(EXPORT_PRESET)" $(EXPORT_DIR)/

run:
	$(GODOT) --path .

test:
	$(GODOT) --headless --script tests/test_mtf_parser.gd

lint:
	@if command -v $(GDLINT) >/dev/null 2>&1; then \
		$(GDLINT) src/; \
	else \
		echo "gdlint not found — install with: pip install gdtoolkit"; \
	fi

export:
	$(GODOT) --headless --export-release "$(EXPORT_PRESET)" $(EXPORT_DIR)/

clean:
	rm -rf $(EXPORT_DIR)/
	rm -f *.pck *.zip
