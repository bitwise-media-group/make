# license.mk — SPDX header injection/verification via addlicense.
# Requires gotools.mk (provides $(ADDLICENSE), installed from .addlicense-version).
ifndef MK_LICENSE_INCLUDED
MK_LICENSE_INCLUDED := 1

# Canonical copyright holder for the whole ecosystem. Do not vary the spelling
# per repo — a single value here is the point. Override only if a repo genuinely
# needs a different holder.
LICENSE_HOLDER ?= BitWise Media Group Ltd

# One -ignore flag per non-empty line in .licenseignore, quoted to survive the
# shell. A repo with no .licenseignore simply gets no ignores.
LICENSE_IGNORE ?= $(foreach pattern,$(shell cat .licenseignore 2>/dev/null),-ignore '$(pattern)')

.PHONY: license license-check
license: $(ADDLICENSE) ## inject SPDX license headers (addlicense)
	@ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) .

# check-mode counterpart wired into the `lint` aggregate; no `## ` so it stays
# out of `help`.
license-check: $(ADDLICENSE)
	@ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) -check .

endif
