# license.mk — SPDX header injection/verification via addlicense.
ifndef MK_LICENSE_INCLUDED
MK_LICENSE_INCLUDED := 1

# Canonical copyright holder for the whole ecosystem. Do not vary the spelling
# per repo — a single value here is the point. Override only if a repo genuinely
# needs a different holder.
LICENSE_HOLDER ?= BitWise Media Group Ltd

# addlicense is pinned in the repo's tools/go.mod and run via `go tool`. Repos
# without a separate tools module set `ADDLICENSE := go tool addlicense` (the
# root go.mod carries the tool directive) before the include.
ADDLICENSE ?= go tool -modfile=tools/go.mod addlicense

# One -ignore flag per non-empty line in .licenseignore, quoted to survive the
# shell. A repo with no .licenseignore simply gets no ignores.
LICENSE_IGNORE ?= $(foreach pattern,$(shell cat .licenseignore 2>/dev/null),-ignore '$(pattern)')

.PHONY: license license-check
license: ## inject SPDX license headers (addlicense)
	@ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) .

# check-mode counterpart wired into the `lint` aggregate; no `## ` so it stays
# out of `help`.
license-check:
	@ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) -check .

endif
