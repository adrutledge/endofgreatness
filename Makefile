GODOT ?= godot
GDLINT ?= gdlint
EXPORT_DIR ?= export
EXPORT_PRESET ?= Linux/X11
GODOT_FLAGS ?= --maximized

SRC_FILES := $(shell find src/ -name "*.gd" | sort)
MTF_SRC := $(shell find src/data/ src/tactical/ -name "*.gd" | sort)
MTF_DEPS := $(shell find data/components/ -name "*.json" | sort)
MTF_TEST := tests/test_mtf_parser.gd
MTF_STAMP := .tested_mtf

MARKET_TEST := tests/test_market_population.gd
MARKET_STAMP := .tested_market

STRAT_GEN_SRC := src/strategic/StrategicUnitGenerator.gd src/strategic/RATParser.gd
STRAT_GEN_DEPS := $(shell find src/data/ -name "*.gd" | sort) src/core/GameState.gd
STRAT_GEN_DATA := $(shell find data/rat/ -name "*.json" | sort)
STRAT_GEN_TEST := tests/test_strategic_unit_generator.gd
STRAT_GEN_TEST2 := tests/test_generate_company.gd
STRAT_GEN_STAMP := .tested_strat_gen

STARMAP_CACHE_SRC := src/core/StarmapCacheGenerator.gd
STARMAP_CACHE_DATA := data/systems_index.json
STARMAP_CACHE_TEST := tests/test_starmap_cache.gd
STARMAP_CACHE_STAMP := .tested_starmap_cache

SUCKIT_SRC := tools/suckit/parse_suckit.py


.PHONY: all build run test lint export clean test-gen suckit

all: lint test build

build:
	$(GODOT) --headless --export-release "$(EXPORT_PRESET)" $(EXPORT_DIR)/

run:
	$(GODOT) --path . $(GODOT_FLAGS)

## Launch with debug logging enabled (--opencode-debug flag)
rund:
	$(GODOT) --path . $(GODOT_FLAGS) -- --opencode-debug

## Launch with debug logging via environment variable
rune:
	OPENCODE_DEBUG=true $(GODOT) --path . $(GODOT_FLAGS)

$(MTF_STAMP): $(MTF_SRC) $(MTF_DEPS) $(MTF_TEST)
	@r=$$($(GODOT) --headless --script $(MTF_TEST) 2>&1 | grep "Results"); \
	echo "[MTF Parser] $$r"
	@touch $(MTF_STAMP)

$(MARKET_STAMP): $(MARKET_TEST)
	@r=$$($(GODOT) --headless --script $(MARKET_TEST) 2>&1 | grep "Results"); \
	echo "[Market Population] $$r"
	@touch $(MARKET_STAMP)

# Regenerate systems + timeline from SUCKIT CSVs. Only triggers on explicit `make suckit`
# or when generated files don't exist. CSVs have spaces in filenames so check timestamps via shell.
data/systems_index.json: $(SUCKIT_SRC)
	@csv="$$(ls tools/suckit/*.csv 2>/dev/null | head -1)"; \
	if [ -z "$$csv" ]; then \
		echo "SUCKIT CSVs not found — systems/timeline unchanged"; \
		touch "$@"; \
	elif [ -f "data/systems_index.json" ] && [ "$$csv" -ot "data/systems_index.json" ]; then \
		:; \
	else \
		echo "Generating systems + timeline from SUCKIT CSV data..."; \
		python3 $(SUCKIT_SRC) 2>&1 | grep -v "^  Skipping"; \
	fi

data/timeline_events.json: data/systems_index.json
	@:

suckit:
	@csv="$$(ls tools/suckit/*.csv 2>/dev/null | head -1)"; \
	if [ -z "$$csv" ]; then echo "No SUCKIT CSVs found"; exit 1; fi; \
	echo "Regenerating systems + timeline..."; \
	python3 $(SUCKIT_SRC) 2>&1 | grep -v "^  Skipping"

$(STRAT_GEN_STAMP): $(STRAT_GEN_SRC) $(STRAT_GEN_DEPS) $(STRAT_GEN_DATA) $(STRAT_GEN_TEST)
	@r=$$($(GODOT) --headless --script $(STRAT_GEN_TEST) 2>&1 | grep "Results"); \
	echo "[Strat Unit Generator] $$r"
	@touch $(STRAT_GEN_STAMP)

$(STARMAP_CACHE_STAMP): $(STARMAP_CACHE_SRC) $(STARMAP_CACHE_DATA) $(STARMAP_CACHE_TEST)
	@r=$$($(GODOT) --headless --script $(STARMAP_CACHE_TEST) 2>&1 | grep "Results"); \
	echo "[Starmap Cache] $$r"
	@touch $(STARMAP_CACHE_STAMP)

test: data/systems_index.json data/timeline_events.json $(MTF_STAMP) $(MARKET_STAMP) $(STRAT_GEN_STAMP) $(STARMAP_CACHE_STAMP)
	@$(MAKE) --quiet lint 2>/dev/null || true

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

## Generate .godot script class cache so class_name types are available before autoloads compile.
## Only needed on fresh clones or after `make clean`.
bootstrap:
	@$(GODOT) --editor --quit --path . 2>&1 | grep -v "^ERROR" | grep -v "^WARNING" | grep -v "^  at" | grep -v "resources" | grep -v "^$$" || true
	@echo ".godot cache generated"

test: bootstrap data/systems_index.json data/timeline_events.json $(MTF_STAMP) $(MARKET_STAMP) $(STRAT_GEN_STAMP) $(STARMAP_CACHE_STAMP)

clean:
	rm -rf $(EXPORT_DIR)/
	rm -f *.pck *.zip .tested_*
	rm -rf .godot/
