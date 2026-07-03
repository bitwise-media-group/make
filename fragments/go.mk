# go.mk — build/test/lint/release for a Go application.
#
# Set APP (output binary) and APP_PKG (main package) in the repo Makefile before
# the include. Everything else has a sensible default and is overridable.
ifndef MK_GO_INCLUDED
MK_GO_INCLUDED := 1

APP     ?= $(notdir $(CURDIR))
APP_PKG ?= .
MODULE  ?= $(shell go list -m 2>/dev/null)

# Go developer CLIs (golangci-lint, govulncheck, gotestsum, gocover-cobertura,
# goreleaser, addlicense) are pinned in tools/go.mod — a separate module so their
# dependency graphs never touch the app's go.mod — and invoked via `go tool`:
# compiled into the build cache on first use, no GOBIN, no binaries to manage.
TOOL ?= go tool -modfile=tools/go.mod

# Version metadata stamped into the binary via -ldflags. GoReleaser injects the
# same vars at the same import path on tagged releases. Point VERSION_PKG at the
# package that declares Version/Commit/BuildDate.
VERSION     ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
DATE        ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
VERSION_PKG ?= $(MODULE)/internal/version
LDFLAGS     ?= -s -w \
	-X $(VERSION_PKG).Version=$(VERSION) \
	-X $(VERSION_PKG).Commit=$(COMMIT) \
	-X $(VERSION_PKG).BuildDate=$(DATE)

# Extra build tags (e.g. an embedded UI: BUILD_TAGS := withui).
BUILD_TAGS     ?=
GO_BUILD_FLAGS ?= -trimpath $(if $(BUILD_TAGS),-tags $(BUILD_TAGS),)

# Fuzzing: `make fuzz` runs one target (FUZZ=) for FUZZTIME over FUZZ_PKG.
# `go test -fuzz` accepts a single package only, so FUZZ_PKG must name one.
FUZZ_PKG ?= ./...
FUZZ     ?= .
FUZZTIME ?= 20s

.PHONY: tidy go-fmt go-lint go-test go-build snapshot release fuzz
tidy: ## tidy the go module graph
	@ rm -f go.sum; go mod tidy

# Auto-fix pass wired into the `fmt` aggregate.
go-fmt:
	@ go fmt ./...
	@ $(TOOL) golangci-lint run --fix

# Check-mode pass wired into the `lint` aggregate.
go-lint:
	@ $(TOOL) golangci-lint run
	@ $(TOOL) govulncheck ./...

# -covermode=atomic is the race-safe counter mode -race requires. gotestsum runs
# the suite and writes a JUnit report in one pass (propagating the exit code a
# bare `go test | …` pipe would swallow); gocover-cobertura turns the profile
# into Cobertura XML. coverage/ is where the reusable CI workflow uploads from.
go-test:
	@ mkdir -p coverage
	@ $(TOOL) gotestsum --junitfile coverage/junit.xml -- \
		-race -covermode=atomic -coverprofile=coverage/coverage.out ./...
	@ $(TOOL) gocover-cobertura <coverage/coverage.out >coverage/cobertura-coverage.xml

go-build:
	@ CGO_ENABLED=0 go build $(GO_BUILD_FLAGS) -ldflags "$(LDFLAGS)" -o $(APP) $(APP_PKG)

# --skip=sign: cosign keyless signing needs the GitHub Actions OIDC token, so it
# only works in the release workflow — locally it would fail or prompt.
snapshot: ## build a local release snapshot (binaries + archives, no publish or signing)
	@ $(TOOL) goreleaser release --snapshot --clean --skip=sign

release: ## build and publish a release (needs a vX.Y.Z tag + creds)
	@ $(TOOL) goreleaser release --clean

fuzz: ## fuzz one target (FUZZ=FuzzName FUZZTIME=20s FUZZ_PKG=./pkg)
	@ go test -run '^$$' -fuzz '^$(FUZZ)$$' -fuzztime $(FUZZTIME) $(FUZZ_PKG)

endif
