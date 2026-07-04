# go-cli.mk — archetype for a Go CLI application (dotty, evolve, gh-claude).
#
# Usage (repo Makefile):
#     APP     := dotty
#     APP_PKG := ./cmd
#     include make/go-cli.mk
#
# Wires the fragment helpers into the canonical lint/build/test/ci/pr contract.
# The canonical targets are pure prerequisite aggregators (no recipe), so a repo
# can extend them by adding prerequisites, e.g. `build: ui` or `pr: docs`.
ifndef MK_GO_CLI_INCLUDED
MK_GO_CLI_INCLUDED := 1

# Directory of this archetype (…/make/), captured before any include shifts
# $(MAKEFILE_LIST); fragments are resolved relative to it.
MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MK_DIR)fragments/common.mk
include $(MK_DIR)fragments/gotools.mk
include $(MK_DIR)fragments/license.mk
include $(MK_DIR)fragments/node.mk
include $(MK_DIR)fragments/go.mk
include $(MK_DIR)fragments/docs.mk

.PHONY: fmt lint build test ci pr
fmt:   go-fmt fmt-prose license          ## format go + prose, inject license headers
lint:  license-check go-lint lint-prose  ## all check-mode static analysis
build: go-build                          ## build the application binary
test:  go-test                           ## run the unit tests with coverage
ci:    lint test build                   ## the gates the reusable CI workflow runs
pr:    tidy fmt lint test build commit   ## full local gate before a pull request

# `docs` is intentionally left to the repo — regenerating a CLI reference is
# app-specific (`./$(APP) docs …`). A repo defines it and appends to the gate:
#     docs: build ; @ ./$(APP) docs --out docs/cli --format markdown && $(MAKE) docs-build
#     pr: docs
# `serve`, `docs-build`, and `sync` come ready-made from docs.mk.

endif
