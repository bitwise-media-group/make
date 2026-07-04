# Shared Makefiles for the bitwise-media-group ecosystem

A proposal for what this `make` repository should contain, so that the ~15 sibling repositories can consume a common set
of Makefile fragments via git submodule (bumped by Dependabot's `gitsubmodule` ecosystem) instead of each maintaining
its own drifting copy.

## 1. What the scan found

Every repo's `Makefile` is a **contract with the reusable CI/release workflows** in
`bitwise-media-group/github-workflows`. `ci.yaml` runs a matrix of `make lint`, `make build`, `make test` (and opt-in
`make e2e`); `release.yaml` drives GoReleaser / Zensical directly off config presence. Those four canonical target names
— `lint`, `build`, `test`, `e2e` — are load-bearing and must survive any refactor unchanged.

Underneath that contract the twelve Makefiles fall into **six archetypes**:

| Archetype               | Repos                                                       | Tooling signature                                                                                               |
| ----------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Go CLI**              | `dotty`, `evolve`, `gh-claude`                              | GoReleaser, `go tool -modfile=tools/go.mod`, LDFLAGS version stamping, gotestsum→cobertura, Zensical docs, `uv` |
| **Node Action**         | `ff-merge`, `setup-evolve`¹                                 | biome + tsc, rollup bundle, vitest coverage, committed `dist/`                                                  |
| **Node library**        | `design-system`¹, `evolve-design-system`¹                   | tsup build, `tsc --noEmit`                                                                                      |
| **Docs site**           | `bitwise-media-group.github.io`, `podcast-workflow`         | Zensical + `uv`, prettier, markdownlint                                                                         |
| **Markdown/config lib** | `github-workflows`, `skills`, `.github`, `github-settings`¹ | prettier + markdownlint, no-op `build`/`test`/`e2e`                                                             |
| **Terraform**           | `cloud-accounts`, `safe-settings`¹                          | `terraform` via `dotty env run`, tflint, terraform-docs                                                         |

¹ Repos that have **no Makefile yet** — onboarding them is part of the win.

### The duplication, concretely

These blocks are copy-pasted (with drift) across the repos that have Makefiles:

- **`help`** — the same grep/awk one-liner in 6 repos, with column widths that have drifted to 10, 12, 15, and 16, and
  grep-vs-awk variants.
- **`LICENSE_HOLDER` / `LICENSE_IGNORE`** — the `.licenseignore` → `-ignore` fold appears in 7 repos.
- **`node_modules` sentinel** — `npm ci --ignore-scripts --no-fund; touch` in 7 repos.
- **`commit`** — `if [ -x ./commit.sh ]; then ./commit.sh; fi` in 4 repos.
- **Go version stamping** — the `VERSION`/`COMMIT`/`DATE`/`LDFLAGS` block is byte-for-byte identical in `dotty` and
  `evolve`, near-identical in `gh-claude`.
- **Go `test`** — the gotestsum + gocover-cobertura recipe is identical across all three Go repos.
- **`snapshot` / `release`** — identical GoReleaser invocations in all three.
- **Zensical `serve` / `docs` / `sync`** — repeated across the Go and docs repos.

### Inconsistencies worth fixing while we centralise

Centralising forces these into one canonical form (a feature, not a side effect):

1. **License holder** has drifted into four spellings: `Bitwise Media Group Ltd`, `Bitwise Media Group Ltd.` (trailing
   dot — `dotty`, `gh-claude`), `BitWise Media Group Ltd` (capital W — `github-workflows`, `ff-merge`), and the
   SPDX-header form. Pick one.
2. **`addlicense` invocation** appears three ways: `go tool addlicense`, `go tool -modfile=tools/go.mod addlicense`, and
   `go -C tools tool addlicense`.
3. **npm script names**: `format` / `format:check` in 6 repos but `fmt` / `fmt:check` in `github-workflows`;
   `podcast-workflow` has no lint/format scripts at all (calls the CLIs from `node_modules/.bin` directly).

## 2. Recommended architecture

A **two-layer library**: small composable _fragments_ that each own one capability, and _archetype_ files that wire
fragments into the canonical `lint`/`build`/`test`/`e2e`/`ci`/`pr` contract. A consuming repo usually includes **one
archetype line**; power users compose fragments directly.

```text
make/                      # this repo, mounted as a submodule at ./make
├── fragments/             # composable building blocks, one capability each
│   ├── common.mk          #   .DEFAULT_GOAL, help, commit, .NOTPARALLEL
│   ├── license.mk         #   LICENSE_HOLDER, .licenseignore, license/license-check
│   ├── node.mk            #   node_modules sentinel, fmt-prose/lint-prose
│   ├── go.mk              #   version stamping, tidy, go-{fmt,lint,test,build}, snapshot, release, fuzz
│   ├── docs.mk            #   zensical sync/docs-build/serve (uv)
│   ├── action.mk          #   biome/tsc lint, rollup build, vitest test
│   ├── terraform.mk       #   generalised cloud.mk: init/plan/apply/tf-{fmt,lint,docs}
│   └── noop.mk            #   build/test/e2e no-ops for docs/config repos
└── <archetype>.mk         # wires fragments into the canonical contract
    ├── go-cli.mk          #   (top level, so consumers write `include make/go-cli.mk`)
    ├── node-action.mk
    ├── node-lib.mk
    ├── docs-site.mk
    ├── markdown-lib.mk
    └── terraform.mk
```

### Consumption model

This ecosystem already proves the pattern: `cloud-accounts/environments/cloud.mk` is `include`d by one-line child
Makefiles. We generalise that across repos via submodule.

```makefile
# dotty/Makefile — the whole thing
APP     := dotty
APP_PKG := ./cmd
include make/go-cli.mk

# repo-local extras that don't belong in the shared library stay here:
.PHONY: link run
link: build ; @ ln -fs $(CURDIR)/$(APP) /usr/local/bin ...
```

```makefile
# github-workflows/Makefile — the whole thing
include make/markdown-lib.mk
```

Dependabot bumps the submodule pointer; `.gitmodules` pins the mount at `make/`.

### Why a submodule, and not a package

The shared content is Makefile fragments that GNU Make `include`s from a path in the working tree — so it must be
**present after checkout at a stable path**, for `make pr` locally _and_ `make lint` in CI. That constraint is what
rules out the package-manager alternatives, because each only reaches the repos that already have that toolchain:

- **npm dev-dependency** (`include node_modules/@bitwise-media-group/make/*.mk`) — real semver via the npm Dependabot
  ecosystem, and reuses the `node_modules` step. But `cloud-accounts`, `github-settings`, `safe-settings`, and `.github`
  have no `package.json`; and it has a chicken-and-egg — `make lint` would `include` a file that only exists after
  `npm ci`, whose target lives _in_ that file.
- **Go tool pinned in `tools/go.mod`** — first-class semver from the gomod ecosystem, matches the `go tool` convention.
  But `ff-merge`, `setup-evolve`, and `design-system` are pure-Node and would gain a Go toolchain just for this.
- **git subtree** — vendors cleanly but Dependabot has no support; updates would be manual `git subtree pull`.

By repo count: npm reaches ~11/15, Go ~9/15, **submodule 15/15**. The submodule is the only language-agnostic,
present-after-checkout, Dependabot-native option — the local-execution complement to the reusable _workflows_ the fleet
already shares via SHA-pinned `uses:`.

Its one real weakness is update **granularity**: Dependabot's `gitsubmodule` ecosystem advances the recorded SHA to the
latest commit on the tracked branch — no semver, no changelog. Control the blast radius by tracking a dedicated release
branch rather than `main`:

```ini
# .gitmodules in each consuming repo
[submodule "make"]
 path = make
 url = https://github.com/bitwise-media-group/make.git
 branch = release
```

Fast-forward `release` only on tagged releases; `main` stays the working branch. Dependabot then proposes a bump only
when a release is cut.

### Go developer tools: pinned centrally, installed on demand

The pinned Go CLIs (`addlicense`, `golangci-lint`, `govulncheck`, `gotestsum`, `gocover-cobertura`, `goreleaser`,
`syft`, `tflint`, `terraform-docs`, `actionlint`) are **not** vendored through a `tools/go.mod`. `go tool` management is
dropped on purpose — golangci-lint breaks under it and documents that as an unsupported use case — in favour of:

- a `.<tool>-version` file **at this library's root** pinning `<version> <sha>` — the tag plus the immutable git commit
  SHA it resolved to (`.golangci-lint-version` → `v2.12.2 c0d3ddc9…`) — and a `.go-version` pinning the toolchain that
  installs them;
- `fragments/gotools.mk`, which `go install`s each tool **by SHA** into a repo-local `.bin/` the first time a target
  needs it, and reinstalls it when the pin changes.

Pinning the SHA (not the tag) is the supply-chain guarantee: a moved or re-pointed upstream tag can't substitute
different code, and Go's checksum DB verifies the fetch on top. Net effect: a consuming repo needs **zero** tool
configuration — the `make/` submodule carries recipes _and_ pins — and a tool is bumped fleet-wide by one commit here +
a submodule bump. The versions are lifted verbatim from the current `tools/go.mod`s, so the switch is
behaviour-preserving.

Losing the gomod ecosystem's auto-bumps is covered by `.github/workflows/update-go-tools.yaml`: a daily job runs
`scripts/update-go-tools.sh`, which advances each pin (version + SHA) to the newest release at least **7 days old** — a
Dependabot-style cooldown against malicious/broken releases — and opens one `fix(deps):` PR.

### Two CI changes, fleet-wide

Both land once in `bitwise-media-group/github-workflows` (`ci.yaml`) and reach every consumer; both are no-ops in repos
that don't opt in:

1. **`submodules: true`** on the `make` matrix job and `e2e` job checkouts — `actions/checkout` doesn't fetch submodules
   by default, so without this the library isn't on disk when `make lint` runs. A no-op where there's no `make/`
   submodule.
2. **Tooling `setup-go` off `make/.go-version`** — the tools-only Go setup step (previously keyed on a `go.work`) now
   also fires when `make/.go-version` exists, so a non-Go repo still gets a toolchain to `go install` the pinned CLIs
   once it drops its `tools/go.mod`. Backward-compatible: repos still on `go.work` are unaffected.

Release/security workflows are untouched: they drive GoReleaser/Zensical/CodeQL directly and never `include` the
library. Locally, `git config --global submodule.recurse true` removes most "forgot to init" friction (worth a line in
each repo's contributing notes).

### Two Make mechanics that make this robust

- **Fragments export _namespaced_ helper targets** (`go-lint`, `lint-prose`, `go-build`), and the **archetype**
  aggregates them into the canonical name via prerequisites: `lint: license-check go-lint lint-prose`. This avoids
  "overriding recipe" collisions when two fragments both contribute to `lint`.
- **Overridable knobs use `?=`** so a repo sets `APP`, `LICENSE_HOLDER`, `golangci-lint_VERSION`, etc. _before_ the
  include. Fragments include their siblings by path relative to themselves —
  `include $(dir $(lastword $(MAKEFILE_LIST)))../fragments/common.mk` — so it works regardless of the consumer's working
  directory.

## 3. Sketch of the core fragments

Illustrative, not final — enough to show the shape.

```makefile
# fragments/common.mk
.DEFAULT_GOAL := help
.PHONY: help commit
help: ## list available targets
 @ grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort \
  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
commit: ## run ./commit.sh (agent-prepared batch) if present
 @ if [ -x ./commit.sh ]; then ./commit.sh; fi
```

```makefile
# fragments/gotools.mk (excerpt) — go install pinned CLIs by SHA, no tools/go.mod
MK_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)  # …/make
TOOLS_BIN ?= $(CURDIR)/.bin
define gotool  # $(call gotool,<binary>,<go install path>); pin is "<version> <sha>"
$(1)_SHA := $$(shell cut -d' ' -f2 "$(MK_ROOT)/.$(1)-version")
$(TOOLS_BIN)/$(1): $(MK_ROOT)/.$(1)-version
 @ GOBIN="$(TOOLS_BIN)" go install "$(2)@$$($(1)_SHA)"   # @sha, not @tag
endef
$(eval $(call gotool,addlicense,github.com/google/addlicense))
ADDLICENSE := $(TOOLS_BIN)/addlicense
```

```makefile
# fragments/license.mk  (uses $(ADDLICENSE) from gotools.mk)
LICENSE_HOLDER ?= BitWise Media Group Ltd
LICENSE_IGNORE := $(foreach p,$(shell cat .licenseignore 2>/dev/null),-ignore '$(p)')
license: $(ADDLICENSE) ## inject SPDX license headers
 @ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) .
```

```makefile
# fragments/go.mk  (excerpt) — tool binaries come from gotools.mk
APP     ?= $(notdir $(CURDIR))
APP_PKG ?= .
MODULE  ?= $(shell go list -m)
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS ?= -s -w -X $(MODULE)/internal/version.Version=$(VERSION) ...
go-test: $(GOTESTSUM) $(GOCOVER_COBERTURA)
 @ mkdir -p coverage
 @ $(GOTESTSUM) --junitfile coverage/junit.xml -- \
  -race -covermode=atomic -coverprofile=coverage/coverage.out ./...
 @ $(GOCOVER_COBERTURA) <coverage/coverage.out >coverage/cobertura-coverage.xml
go-build:
 @ CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o $(APP) $(APP_PKG)
```

```makefile
# go-cli.mk
H := $(dir $(lastword $(MAKEFILE_LIST)))
include $(H)fragments/common.mk
include $(H)fragments/license.mk
include $(H)fragments/node.mk
include $(H)fragments/go.mk
include $(H)fragments/docs.mk
.PHONY: lint build test ci pr
lint:  license-check go-lint lint-prose  ## all check-mode static analysis
build: go-build                          ## build the binary
test:  go-test                           ## unit tests with coverage
ci:    lint test build                   ## CI gate
pr:    tidy fmt lint test build docs commit ## full local gate
```

## 4. Per-repo migration map

| Repo                            | Include                                         | Stays repo-local                                  |
| ------------------------------- | ----------------------------------------------- | ------------------------------------------------- |
| `dotty`                         | `go-cli.mk`                                     | `link`, `run`, `fuzz` defaults                    |
| `evolve`                        | `go-cli.mk`                                     | `ui`, `bench`, `smoke`, GOOS lint matrix, `run`   |
| `gh-claude`                     | `go-cli.mk`                                     | `install`, `policy`, `run`                        |
| `ff-merge`                      | `node-action.mk`                                | —                                                 |
| `setup-evolve`                  | `node-action.mk`                                | _(new Makefile — currently none)_                 |
| `design-system`                 | `node-lib.mk`                                   | `build:bundle` step _(new Makefile)_              |
| `evolve-design-system`          | `node-lib.mk` or `markdown-lib.mk`              | _(new Makefile)_                                  |
| `bitwise-media-group.github.io` | `docs-site.mk`                                  | `worker/node_modules`, worker `serve`             |
| `podcast-workflow`              | `docs-site.mk`                                  | `upgrade` (cooldown-bypass warning)               |
| `github-workflows`              | `markdown-lib.mk`                               | `zizmor` lint, `.NOTPARALLEL`                     |
| `skills`                        | `markdown-lib.mk`                               | `triggers`/`evals`/`report` (evolve)              |
| `.github`                       | `markdown-lib.mk`                               | —                                                 |
| `cloud-accounts`                | `terraform.mk` (+ keep root fan-out aggregator) | `FANOUT` aggregator                               |
| `github-settings`               | `markdown-lib.mk`                               | `org-config.sh`/`repo-config.sh` _(new Makefile)_ |
| `safe-settings`                 | `terraform.mk`                                  | `bootstrap`, `container` _(new Makefile)_         |

Repo-specific targets (`evolve`'s `ui`/`smoke`, `gh-claude`'s `policy`, `podcast-workflow`'s `upgrade`) stay in the
repo's own `Makefile` below the `include` — the library covers the common 80%, not the long tail.

Each migrating repo also **deletes** its `tools/go.mod`, `tools/go.sum`, and (for non-Go repos) its tools-only
`go.work`, dropping the `tools`-module entry from its `dependabot.yaml`; the pinned CLIs now come from the library's
`.<tool>-version` files. Non-Go repos gain nothing to configure — the `make/` submodule supplies `make/.go-version`. Add
`.bin/` and `coverage/` to each repo's `.gitignore`.

## 5. Decisions (resolved)

1. **Submodule mount path** — `make/`.
2. **Canonical license holder string** — `BitWise Media Group Ltd` (capital "W", no trailing dot); set in
   `fragments/license.mk`, overridable via `LICENSE_HOLDER`.
3. **`addlicense` default** — `go tool -modfile=tools/go.mod addlicense`, with `ADDLICENSE := go tool addlicense` in the
   three markdown/docs repos that have no `tools/` module.
4. **npm-script normalisation** — `format` / `format:check` / `lint` / `lint:fix`; `github-workflows` renames
   `fmt`→`format`, `podcast-workflow` gains the scripts.
5. **Distribution** — git submodule at `make/`, tracked against a `release` branch (see §2), bumped by the Dependabot
   `gitsubmodule` ecosystem.

## 6. Suggested rollout

1. **Done** — `fragments/` + archetypes landed in this repo and validated (`make -n` across every archetype: clean
   parse, no recipe collisions, the Go `pr` sequence matches the hand-written Makefiles). Cut `v0.1.0` and fast-forward
   the `release` branch to it.
2. **Done** — `submodules: true` and `.go-version` tooling setup added to the reusable `ci.yaml`; the library dogfoods
   its own `markdown-lib` archetype (`make lint`/`build`/`test` green here), so its own CI is the first proof the
   fragments work end-to-end.
3. Pilot on **one Go repo** (`dotty`) and **one markdown repo** (`github-workflows`): add the submodule with
   `branch = release`, replace the Makefile, confirm `make lint build test` is byte-for-byte equivalent to today's CI
   run.
4. Roll out to the rest by archetype; add `.gitmodules` + a `gitsubmodule` entry to each repo's `dependabot.yaml`.
5. Onboard the five Makefile-less repos onto the CI contract.
