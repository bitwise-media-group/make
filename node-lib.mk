# node-lib.mk — archetype for a Node/TypeScript library (design-system,
# evolve-design-system).
#
# Usage (repo Makefile):
#     include make/node-lib.mk
#
# Minimal by design: a tsup/tsc build and a type-check. A library that adds the
# ecosystem prose scripts (format / lint) can switch to including node.mk's
# fmt-prose / lint-prose and append them to fmt / lint.
ifndef MK_NODE_LIB_INCLUDED
MK_NODE_LIB_INCLUDED := 1

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MK_DIR)fragments/common.mk
include $(MK_DIR)fragments/node.mk

.PHONY: lib-lint lib-build lint build test e2e ci pr
# `npm run typecheck` → tsc --noEmit; no `## ` so it stays out of help.
lib-lint: node_modules
	@ npm run typecheck

lib-build: node_modules
	@ npm run build

lint:  lib-lint   ## type-check the library (tsc --noEmit)
build: lib-build  ## build the library bundle (tsup)
test: ## no-op: no unit tests yet
	@:
e2e: ## no-op: no end-to-end tests
	@:
ci:    lint build test        ## the gates the reusable CI workflow runs
pr:    lint build commit      ## full local gate before a pull request

endif
