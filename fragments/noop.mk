# noop.mk — canonical CI targets as no-ops.
#
# For repos with nothing to compile, unit-test, or exercise end-to-end (Markdown
# / YAML libraries). The reusable ci/release workflows call `make build`,
# `make test`, and (opt-in) `make e2e` unconditionally, so they must exist and
# succeed. A repo that needs a real `build` includes go.mk / action.mk instead of
# this and gets only test/e2e stubs from its archetype.
ifndef MK_NOOP_INCLUDED
MK_NOOP_INCLUDED := 1

.PHONY: build test e2e
build: ## no-op: nothing to build
	@:
test: ## no-op: nothing to test
	@:
e2e: ## no-op: no end-to-end tests
	@:

endif
