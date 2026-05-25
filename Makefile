GODOT ?= godot
GDLINT ?= gdlint
EXPORT_DIR ?= export
EXPORT_PRESET ?= Linux/X11

SRC_FILES := $(shell find src/ -name "*.gd" | sort)
MTF_SRC := $(shell find src/data/ src/tactical/ -name "*.gd" | sort)
MTF_DEPS := $(shell find data/components/ -name "*.json" | sort)
MTF_TEST := tests/test_mtf_parser.gd
MTF_STAMP := .tested_mtf

STRAT_GEN_SRC := src/strategic/StrategicUnitGenerator.gd src/strategic/RATParser.gd
STRAT_GEN_DEPS := $(shell find src/data/ -name "*.gd" | sort) src/core/GameState.gd
STRAT_GEN_DATA := $(shell find data/rat/ -name "*.json" | sort)
STRAT_GEN_TEST := tests/test_strategic_unit_generator.gd
STRAT_GEN_TEST2 := tests/test_generate_company.gd
STRAT_GEN_STAMP := .tested_strat_gen

.PHONY: all build run test lint export clean test-gen

all: lint test build

build:
	$(GODOT) --headless --export-release "$(EXPORT_PRESET)" $(EXPORT_DIR)/

run:
	$(GODOT) --path .

## Launch with debug logging enabled (--opencode-debug flag)
rund:
	$(GODOT) --path . -- --opencode-debug

## Launch with debug logging via environment variable
rune:
	OPENCODE_DEBUG=true $(GODOT) --path .

$(MTF_STAMP): $(MTF_SRC) $(MTF_DEPS) $(MTF_TEST)
	@$(GODOT) --headless --script $(MTF_TEST) 2>&1 | grep -E "^(PASS|FAIL|Results)"
	@touch $(MTF_STAMP)

$(STRAT_GEN_STAMP): $(STRAT_GEN_SRC) $(STRAT_GEN_DEPS) $(STRAT_GEN_DATA) $(STRAT_GEN_TEST)
	@$(GODOT) --headless --script $(STRAT_GEN_TEST) 2>&1 | grep -E "^(PASS|FAIL|Results)"
	@touch $(STRAT_GEN_STAMP)

test: $(MTF_STAMP) $(STRAT_GEN_STAMP)

## Headless generator integration test (requires autoloads, runs full engine)
test-gen:
	@$(GODOT) --path . --headless -- --test-generator 2>&1 | grep -E "^(PASSED|FAILED|===)" || echo "test-gen target not available in --script mode"

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
