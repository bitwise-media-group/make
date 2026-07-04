# gotools.mk — install pinned Go developer CLIs directly, no per-repo tools module.
#
# `go tool` management is deliberately avoided: golangci-lint breaks consistently
# when run that way and its maintainers document it as unsupported. Instead each
# tool is pinned in a `.<tool>-version` file at the root of the make library (this
# submodule) as "<version> <commit-sha>", and installed BY SHA — so a moved or
# re-pointed upstream tag cannot substitute different code (Go's checksum database
# verifies on top). A consuming repo needs no tools/go.mod, no tools/go.sum, and no
# `-modfile=` incantation — just the archetype include. A tool is `go install`ed
# into a repo-local $(TOOLS_BIN) the first time a target needs it, and reinstalled
# whenever its pin changes (bumping the submodule bumps the pin for the whole
# fleet). A repo can still override a pin with `golangci-lint_SHA := <sha>` before
# the include.
ifndef MK_GOTOOLS_INCLUDED
MK_GOTOOLS_INCLUDED := 1

# Absolute path to this library's root (…/make), where the .<tool>-version pins
# live — resolved (immediately, while this fragment is the last-parsed file)
# relative to the fragment, so it is independent of the caller's CWD.
ifndef MK_ROOT
MK_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
endif

# Where installed tool binaries land. Repo-local and git-ignorable; the Go build
# cache under ~/go keeps reinstalls fast.
TOOLS_BIN ?= $(CURDIR)/.bin

# Each .<tool>-version pins `<version> <commit-sha>` — the readable tag plus the
# immutable git SHA it resolved to, exactly as we pin GitHub Actions. Installing by
# SHA (not the tag) means a moved/re-pointed upstream tag cannot slip in different
# code; Go's checksum database verifies the fetch on top of that.
#
# $(call gotool,<binary>,<go install path>): read the pin, and declare an install
# rule that (re)builds $(TOOLS_BIN)/<binary> whenever that pin changes.
define gotool
ifndef $(1)_VERSION
$(1)_VERSION := $$(shell cut -d' ' -f1 "$(MK_ROOT)/.$(1)-version" 2>/dev/null)
endif
ifndef $(1)_SHA
$(1)_SHA := $$(shell cut -d' ' -f2 "$(MK_ROOT)/.$(1)-version" 2>/dev/null)
endif
$(TOOLS_BIN)/$(1): $(MK_ROOT)/.$(1)-version
	@ mkdir -p "$(TOOLS_BIN)"
	@ echo "gotools: installing $(1) $$($(1)_VERSION) @ $$($(1)_SHA)"
	@ GOBIN="$(TOOLS_BIN)" go install "$(2)@$$($(1)_SHA)"
endef

$(eval $(call gotool,addlicense,github.com/google/addlicense))
$(eval $(call gotool,golangci-lint,github.com/golangci/golangci-lint/v2/cmd/golangci-lint))
$(eval $(call gotool,govulncheck,golang.org/x/vuln/cmd/govulncheck))
$(eval $(call gotool,gotestsum,gotest.tools/gotestsum))
$(eval $(call gotool,gocover-cobertura,github.com/boumenot/gocover-cobertura))
$(eval $(call gotool,goreleaser,github.com/goreleaser/goreleaser/v2))
$(eval $(call gotool,syft,github.com/anchore/syft/cmd/syft))
$(eval $(call gotool,tflint,github.com/terraform-linters/tflint))
$(eval $(call gotool,terraform-docs,github.com/terraform-docs/terraform-docs))
$(eval $(call gotool,actionlint,github.com/rhysd/actionlint/cmd/actionlint))

# Invocation variables: use these as both a recipe command and a prerequisite, e.g.
#   license: $(ADDLICENSE) ; @ $(ADDLICENSE) ... .
ADDLICENSE        := $(TOOLS_BIN)/addlicense
GOLANGCI_LINT     := $(TOOLS_BIN)/golangci-lint
GOVULNCHECK       := $(TOOLS_BIN)/govulncheck
GOTESTSUM         := $(TOOLS_BIN)/gotestsum
GOCOVER_COBERTURA := $(TOOLS_BIN)/gocover-cobertura
GORELEASER        := $(TOOLS_BIN)/goreleaser
SYFT              := $(TOOLS_BIN)/syft
TFLINT            := $(TOOLS_BIN)/tflint
TERRAFORM_DOCS    := $(TOOLS_BIN)/terraform-docs
ACTIONLINT        := $(TOOLS_BIN)/actionlint

# Lint the repo's GitHub Actions workflows (no-op where there are none).
.PHONY: actionlint
actionlint: $(ACTIONLINT) ## lint .github/workflows with actionlint
	@ $(ACTIONLINT)

endif
