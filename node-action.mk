# node-action.mk — archetype for a Node/TypeScript GitHub Action
# (ff-merge, setup-evolve).
#
# Usage (repo Makefile):
#     include make/node-action.mk
#
# These Actions ship a committed dist/, so `build` must regenerate it
# reproducibly (the reusable CI fails the PR on a dirty dist/ diff).
ifndef MK_NODE_ACTION_INCLUDED
MK_NODE_ACTION_INCLUDED := 1

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Action repos run lifecycle scripts on install, so use a plain `npm ci` (drop
# the --ignore-scripts default). Set before node.mk so its ?= keeps this value.
NPM_CI_FLAGS :=

include $(MK_DIR)fragments/common.mk
include $(MK_DIR)fragments/node.mk
include $(MK_DIR)fragments/action.mk

.PHONY: fmt lint build test e2e ci pr
fmt:   action-fmt              ## biome --write + prettier (markdown)
lint:  action-lint             ## biome check + tsc --noEmit
build: action-build            ## bundle the action into dist/ (rollup)
test:  action-test             ## vitest with coverage
e2e: ## no-op: running the action for real would mutate refs; covered by unit tests
	@:
ci:    lint build test         ## the gates the reusable CI workflow runs
pr:    fmt lint build test commit ## full local gate before a pull request

endif
