# common.mk — default goal, the `help` listing, and the `commit` handoff.
# Include this first in every archetype. Guarded so a double-include is a no-op.
ifndef MK_COMMON_INCLUDED
MK_COMMON_INCLUDED := 1

# These gates are order-sensitive (fmt must run before lint, license before the
# license-check) and several mutate files in place, so keep make serial even
# under -j: prerequisites of a target are then made left-to-right, never raced.
# The heavy lifting (go test -race, npm, goreleaser) parallelises internally, so
# nothing of value is lost.
.NOTPARALLEL:

.DEFAULT_GOAL := help

# List every target that carries a `## description` comment, across the consuming
# Makefile and every included fragment ($(MAKEFILE_LIST) holds them all). Helper
# targets deliberately omit the comment so they stay out of this listing.
.PHONY: help
help: ## list available targets
	@ grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| sort -u \
		| awk 'BEGIN { FS = ":.*?## " } { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }'

# Run an agent-prepared commit batch if one is waiting. The `pr` gate calls this
# last so a green local run flows straight into the (user-signed) commit.
.PHONY: commit
commit: ## run ./commit.sh (agent-prepared commit batch) if present
	@ if [ -x ./commit.sh ]; then ./commit.sh; fi

endif
