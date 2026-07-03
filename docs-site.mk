# docs-site.mk — archetype for a Zensical documentation site
# (bitwise-media-group.github.io, podcast-workflow).
#
# Usage (repo Makefile):
#     include make/docs-site.mk
#
# `build` renders the site; there is nothing to unit-test, so test/e2e are stubs.
# Repos without a tools/go.mod set `ADDLICENSE := go tool addlicense` first.
ifndef MK_DOCS_SITE_INCLUDED
MK_DOCS_SITE_INCLUDED := 1

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MK_DIR)fragments/common.mk
include $(MK_DIR)fragments/license.mk
include $(MK_DIR)fragments/node.mk
include $(MK_DIR)fragments/docs.mk

.PHONY: fmt lint build test e2e ci pr
fmt:   fmt-prose license          ## format prose, inject license headers
lint:  license-check lint-prose   ## prose lint (prettier + markdownlint) + license check
build: docs-build                 ## render the documentation site (zensical)
test: ## no-op: a docs site has no unit tests
	@:
e2e: ## no-op: no end-to-end tests
	@:
ci:    lint build test            ## the gates the reusable CI workflow runs
pr:    fmt lint build commit      ## full local gate before a pull request

endif
