# Shared Makefiles for the bitwise-media-group ecosystem

A proposal for what this `make` repository should contain, so that the ~15
sibling repositories can consume a common set of Makefile fragments via git
submodule (bumped by Dependabot's `gitsubmodule` ecosystem) instead of each
maintaining its own drifting copy.

## 1. What the scan found

Every repo's `Makefile` is a **contract with the reusable CI/release
workflows** in `bitwise-media-group/github-workflows`. `ci.yaml` runs a matrix
of `make lint`, `make build`, `make test` (and opt-in `make e2e`); `release.yaml`
drives GoReleaser / Zensical directly off config presence. Those four canonical
target names — `lint`, `build`, `test`, `e2e` — are load-bearing and must
survive any refactor unchanged.

Underneath that contract the twelve Makefiles fall into **six archetypes**:

| Archetype | Repos | Tooling signature |
|---|---|---|
| **Go CLI** | `dotty`, `evolve`, `gh-claude` | GoReleaser, `go tool -modfile=tools/go.mod`, LDFLAGS version stamping, gotestsum→cobertura, Zensical docs, `uv` |
| **Node Action** | `ff-merge`, `setup-evolve`¹ | biome + tsc, rollup bundle, vitest coverage, committed `dist/` |
| **Node library** | `design-system`¹, `evolve-design-system`¹ | tsup build, `tsc --noEmit` |
| **Docs site** | `bitwise-media-group.github.io`, `podcast-workflow` | Zensical + `uv`, prettier, markdownlint |
| **Markdown/config lib** | `github-workflows`, `skills`, `.github`, `github-settings`¹ | prettier + markdownlint, no-op `build`/`test`/`e2e` |
| **Terraform** | `cloud-accounts`, `safe-settings`¹ | `terraform` via `dotty env run`, tflint, terraform-docs |

¹ Repos that have **no Makefile yet** — onboarding them is part of the win.

### The duplication, concretely

These blocks are copy-pasted (with drift) across the repos that have Makefiles:

- **`help`** — the same grep/awk one-liner in 6 repos, with column widths that
  have drifted to 10, 12, 15, and 16, and grep-vs-awk variants.
- **`LICENSE_HOLDER` / `LICENSE_IGNORE`** — the `.licenseignore` → `-ignore`
  fold appears in 7 repos.
- **`node_modules` sentinel** — `npm ci --ignore-scripts --no-fund; touch` in 7 repos.
- **`commit`** — `if [ -x ./commit.sh ]; then ./commit.sh; fi` in 4 repos.
- **Go version stamping** — the `VERSION`/`COMMIT`/`DATE`/`LDFLAGS` block is
  byte-for-byte identical in `dotty` and `evolve`, near-identical in `gh-claude`.
- **Go `test`** — the gotestsum + gocover-cobertura recipe is identical across
  all three Go repos.
- **`snapshot` / `release`** — identical GoReleaser invocations in all three.
- **Zensical `serve` / `docs` / `sync`** — repeated across the Go and docs repos.

### Inconsistencies worth fixing while we centralise

Centralising forces these into one canonical form (a feature, not a side effect):

1. **License holder** has drifted into four spellings: `Bitwise Media Group Ltd`,
   `Bitwise Media Group Ltd.` (trailing dot — `dotty`, `gh-claude`),
   `BitWise Media Group Ltd` (capital W — `github-workflows`, `ff-merge`), and
   the SPDX-header form. Pick one.
2. **`addlicense` invocation** appears three ways: `go tool addlicense`,
   `go tool -modfile=tools/go.mod addlicense`, and `go -C tools tool addlicense`.
3. **npm script names**: `format` / `format:check` in 6 repos but `fmt` /
   `fmt:check` in `github-workflows`; `podcast-workflow` has no lint/format
   scripts at all (calls the CLIs from `node_modules/.bin` directly).

## 2. Recommended architecture

A **two-layer library**: small composable *fragments* that each own one
capability, and *archetype* files that wire fragments into the canonical
`lint`/`build`/`test`/`e2e`/`ci`/`pr` contract. A consuming repo usually
includes **one archetype line**; power users compose fragments directly.

```
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

This ecosystem already proves the pattern: `cloud-accounts/environments/cloud.mk`
is `include`d by one-line child Makefiles. We generalise that across repos via
submodule.

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

### Two Make mechanics that make this robust

- **Fragments export *namespaced* helper targets** (`go-lint`, `lint-prose`,
  `go-build`), and the **archetype** aggregates them into the canonical name via
  prerequisites: `lint: license-check go-lint lint-prose`. This avoids
  "overriding recipe" collisions when two fragments both contribute to `lint`.
- **Overridable knobs use `?=`** so a repo sets `APP`, `LICENSE_HOLDER`,
  `ADDLICENSE`, etc. *before* the include. Fragments include their siblings by
  path relative to themselves — `include $(dir $(lastword $(MAKEFILE_LIST)))../fragments/common.mk`
  — so it works regardless of the consumer's working directory.

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
# fragments/license.mk
LICENSE_HOLDER ?= BitWise Media Group Ltd
ADDLICENSE     ?= go tool -modfile=tools/go.mod addlicense
LICENSE_IGNORE := $(foreach p,$(shell cat .licenseignore 2>/dev/null),-ignore '$(p)')
.PHONY: license license-check
license: ## inject SPDX license headers
	@ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) .
license-check:
	@ $(ADDLICENSE) -l mit -c '$(LICENSE_HOLDER)' -s=only $(LICENSE_IGNORE) -check .
```

```makefile
# fragments/go.mk  (excerpt)
APP     ?= $(notdir $(CURDIR))
APP_PKG ?= .
MODULE  ?= $(shell go list -m)
TOOL    ?= go tool -modfile=tools/go.mod
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS ?= -s -w -X $(MODULE)/internal/version.Version=$(VERSION) ...
go-test:
	@ mkdir -p coverage
	@ $(TOOL) gotestsum --junitfile coverage/junit.xml -- \
		-race -covermode=atomic -coverprofile=coverage/coverage.out ./...
	@ $(TOOL) gocover-cobertura <coverage/coverage.out >coverage/cobertura-coverage.xml
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

| Repo | Include | Stays repo-local |
|---|---|---|
| `dotty` | `go-cli.mk` | `link`, `run`, `fuzz` defaults |
| `evolve` | `go-cli.mk` | `ui`, `bench`, `smoke`, GOOS lint matrix, `run` |
| `gh-claude` | `go-cli.mk` | `install`, `policy`, `run` |
| `ff-merge` | `node-action.mk` | — |
| `setup-evolve` | `node-action.mk` | *(new Makefile — currently none)* |
| `design-system` | `node-lib.mk` | `build:bundle` step *(new Makefile)* |
| `evolve-design-system` | `node-lib.mk` or `markdown-lib.mk` | *(new Makefile)* |
| `bitwise-media-group.github.io` | `docs-site.mk` | `worker/node_modules`, worker `serve` |
| `podcast-workflow` | `docs-site.mk` | `upgrade` (cooldown-bypass warning) |
| `github-workflows` | `markdown-lib.mk` | `zizmor` lint, `.NOTPARALLEL` |
| `skills` | `markdown-lib.mk` | `triggers`/`evals`/`report` (evolve) |
| `.github` | `markdown-lib.mk` | — |
| `cloud-accounts` | `terraform.mk` (+ keep root fan-out aggregator) | `FANOUT` aggregator |
| `github-settings` | `markdown-lib.mk` | `org-config.sh`/`repo-config.sh` *(new Makefile)* |
| `safe-settings` | `terraform.mk` | `bootstrap`, `container` *(new Makefile)* |

Repo-specific targets (`evolve`'s `ui`/`smoke`, `gh-claude`'s `policy`,
`podcast-workflow`'s `upgrade`) stay in the repo's own `Makefile` below the
`include` — the library covers the common 80%, not the long tail.

## 5. Decisions needed before scaffolding

1. **Submodule mount path** — `make/` (visible, discoverable) vs `.make/` (tidy root).
2. **Canonical license holder string** — resolved to `BitWise Media Group Ltd`
   (capital "W", no trailing dot); set in `fragments/license.mk` and overridable
   per repo via `LICENSE_HOLDER`.
3. **`addlicense` default** — recommend `go tool -modfile=tools/go.mod addlicense`
   with `ADDLICENSE ?=` override for repos without a `tools/` module.
4. **npm-script normalisation** — standardise on `format` / `format:check` /
   `lint` / `lint:fix`; update `github-workflows` (`fmt`→`format`) and add the
   scripts to `podcast-workflow`.
5. **Onboarding scope** — do we bring the five Makefile-less repos onto the CI
   contract now, or land the library against the twelve existing ones first?

## 6. Suggested rollout

1. Land `fragments/` + `archetypes/` in this repo; tag `v0.1.0`.
2. Pilot on **one Go repo** (`dotty`) and **one markdown repo**
   (`github-workflows`): add the submodule, replace the Makefile, confirm
   `make lint build test` is byte-for-byte equivalent to today's CI run.
3. Roll out to the rest by archetype; enable Dependabot `gitsubmodule` updates.
4. Onboard the five Makefile-less repos onto the CI contract.
