# markdown-lib.mk — archetype for a Markdown/YAML library with nothing to
# compile or test (github-workflows, skills, .github).
#
# Usage (repo Makefile):
#     include make/markdown-lib.mk
#
# Real lint (prose + license); build/test/e2e are no-ops that satisfy the CI and
# release contracts.
ifndef MK_MARKDOWN_LIB_INCLUDED
MK_MARKDOWN_LIB_INCLUDED := 1

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MK_DIR)fragments/common.mk
include $(MK_DIR)fragments/gotools.mk
include $(MK_DIR)fragments/license.mk
include $(MK_DIR)fragments/node.mk
include $(MK_DIR)fragments/noop.mk

.PHONY: fmt lint ci pr
fmt:  fmt-prose license          ## format prose, inject license headers
lint: license-check lint-prose   ## prose lint (prettier + markdownlint) + license check
ci:   lint build test            ## the gates the reusable CI workflow runs
pr:   fmt lint build test commit ## full local gate before a pull request

endif
