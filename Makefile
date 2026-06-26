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

PLAN_MAP_GEN_SRC := src/strategic/PlanetaryMapGenerator.gd
PLAN_MAP_GEN_DATA := src/data/HexMap.gd
PLAN_MAP_GEN_TEST := tests/test_planetary_map_generator.gd
PLAN_MAP_GEN_STAMP := .tested_plan_map_gen

SUCKIT_SRC := tools/suckit/parse_suckit.py


.PHONY: all build run test test-unit test-integration lint check export clean test-gen suckit

all: test

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

$(PLAN_MAP_GEN_STAMP): $(PLAN_MAP_GEN_SRC) $(PLAN_MAP_GEN_DATA) $(PLAN_MAP_GEN_TEST)
	@r=$$($(GODOT) --headless --script $(PLAN_MAP_GEN_TEST) 2>&1 | grep "Results"); \
	echo "[Plan Map Gen] $$r"
	@touch $(PLAN_MAP_GEN_STAMP)

DATA_FORMAT_TEST := tests/test_data_formats.gd
DATA_FORMAT_STAMP := .tested_data_format

$(DATA_FORMAT_STAMP): $(DATA_FORMAT_TEST)
	@r=$$($(GODOT) --headless --script $(DATA_FORMAT_TEST) 2>&1 | grep "Results"); \
	echo "[Data Formats] $$r"
	@touch $(DATA_FORMAT_STAMP)

SAVE_SYSTEM_TEST := tests/test_save_system.gd
SAVE_SYSTEM_STAMP := .tested_save_system

$(SAVE_SYSTEM_STAMP): $(SAVE_SYSTEM_TEST)
	@r=$$($(GODOT) --headless --script $(SAVE_SYSTEM_TEST) 2>&1 | grep "Results"); \
	echo "[Save System] $$r"
	@touch $(SAVE_SYSTEM_STAMP)

MOD_SYSTEM_TEST := tests/test_mod_system.gd
MOD_SYSTEM_STAMP := .tested_mod_system

$(MOD_SYSTEM_STAMP): $(MOD_SYSTEM_TEST)
	@r=$$($(GODOT) --headless --script $(MOD_SYSTEM_TEST) 2>&1 | grep "Results"); \
	echo "[Mod System] $$r"
	@touch $(MOD_SYSTEM_STAMP)

TACTICAL_INTEGRATION_TEST := tests/test_tactical_integration.gd
TACTICAL_INTEGRATION_STAMP := .tested_tactical_integration

$(TACTICAL_INTEGRATION_STAMP): $(TACTICAL_INTEGRATION_TEST)
	@r=$$($(GODOT) --headless --script $(TACTICAL_INTEGRATION_TEST) 2>&1 | grep "Results"); \
	echo "[Tactical Integration] $$r"
	@touch $(TACTICAL_INTEGRATION_STAMP)

AI_EVALUATOR_TEST := tests/test_ai_evaluator.gd
AI_EVALUATOR_STAMP := .tested_ai_evaluator

PARSE_CHECK_TEST := tests/test_parse_check.gd
PARSE_CHECK_STAMP := .tested_parse

$(AI_EVALUATOR_STAMP): $(AI_EVALUATOR_TEST)
	@r=$$($(GODOT) --headless --script $(AI_EVALUATOR_TEST) 2>&1 | grep "Results"); \
	echo "[AI Evaluator] $$r"
	@touch $(AI_EVALUATOR_STAMP)

## Generate .godot script class cache so class_name types are available before autoloads compile.
bootstrap:
	@$(GODOT) --editor --quit --path . 2>&1 | grep -v "^ERROR" | grep -v "^WARNING" | grep -v "^  at" | grep -v "resources" | grep -v "^$$" || true
	@echo ".godot cache generated"

## Fast parse check — validates all .gd files compile without errors.
## Uses godot --editor --quit (same mechanism as bootstrap) but reports
## parse errors instead of suppressing them.
## Catches parse errors and type inference failures in ~10-15s.
.PHONY: check
check:
	@log=$$($(GODOT) --editor --quit --path . 2>&1); \
	parse_errors=$$(echo "$$log" | grep -cE "Parse Error" || true); \
	load_errors=$$(echo "$$log" | grep -cE "Failed to load script.*Parse error" || true); \
	total=$$((parse_errors + load_errors)); \
	if [ "$$total" -gt 0 ]; then \
		echo "$$log" | grep -E "(Parse Error|Failed to load script)" | grep -v "^WARNING" | grep -v "^  at" | head -20; \
		echo "[Check] $$total parse error(s) found"; \
		exit 1; \
	else \
		echo "[Check] All scripts parse OK"; \
	fi

lint:
	@count=$$($(GDLINT) src/ 2>&1 | grep -cE "(Error|Warning)" || true); \
	echo "[Lint] $$count issues found"; \
	if [ "$$count" -gt 0 ]; then \
		$(GDLINT) src/ 2>&1; \
	fi

# Fast unit tests — run during development
UNIT_TESTS := $(MTF_STAMP) $(MARKET_STAMP) $(DATA_FORMAT_STAMP) $(SAVE_SYSTEM_STAMP) $(MOD_SYSTEM_STAMP) $(AI_EVALUATOR_STAMP)

# Slower integration/validation tests — run before merge
INTEGRATION_TESTS := $(STRAT_GEN_STAMP) $(STARMAP_CACHE_STAMP) $(PLAN_MAP_GEN_STAMP) $(TACTICAL_INTEGRATION_STAMP)

test: bootstrap data/systems_index.json data/timeline_events.json $(UNIT_TESTS) $(INTEGRATION_TESTS)

test-unit: bootstrap data/systems_index.json data/timeline_events.json $(UNIT_TESTS)

test-integration: bootstrap data/systems_index.json data/timeline_events.json $(INTEGRATION_TESTS)

clean:
	rm -rf $(EXPORT_DIR)/
	rm -f *.pck *.zip .tested_*
	rm -rf .godot/
