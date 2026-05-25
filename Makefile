GODOT ?= godot
GDLINT ?= gdlint
EXPORT_DIR ?= export
EXPORT_PRESET ?= Linux/X11

SRC_FILES := $(shell find src/ data/components/ -name "*.gd" -o -name "*.json" | sort)
MTF_TEST := tests/test_mtf_parser.gd
MTF_STAMP := .tested_mtf

.PHONY: all build run test lint export clean

all: lint test build

build:
	$(GODOT) --headless --export-release "$(EXPORT_PRESET)" $(EXPORT_DIR)/

run:
	$(GODOT) --path .

$(MTF_STAMP): $(SRC_FILES) $(MTF_TEST)
	@$(GODOT) --headless --script $(MTF_TEST) 2>&1 | grep -E "^(PASS|FAIL|Results)"
	@touch $(MTF_STAMP)

test: $(MTF_STAMP) | build

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
	rm -f *.pck *.zip .tested_*
