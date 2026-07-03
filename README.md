# make

Shared Makefiles for the bitwise-media-group ecosystem. Each repo consumes this
library as a git submodule mounted at `make/` (bumped by Dependabot's
`gitsubmodule` ecosystem) and reduces its own `Makefile` to a few lines.

See [RECOMMENDATION.md](RECOMMENDATION.md) for the design rationale and the
per-repo migration map.

## Layout

```
make/
├── fragments/          # composable building blocks, one capability each
│   ├── common.mk       #   .DEFAULT_GOAL, help, commit, .NOTPARALLEL
│   ├── license.mk      #   LICENSE_HOLDER, .licenseignore, license / license-check
│   ├── node.mk         #   node_modules sentinel, fmt-prose / lint-prose
│   ├── go.mk           #   version stamping, tidy, go-{fmt,lint,test,build}, snapshot, release, fuzz
│   ├── docs.mk         #   zensical sync / docs-build / serve (uv)
│   ├── action.mk       #   biome + tsc + rollup + vitest helpers
│   ├── terraform.mk    #   init / plan / apply / tf-{fmt,lint,docs}
│   └── noop.mk         #   build / test / e2e no-ops
└── <archetype>.mk      # wires fragments into the canonical contract
    ├── go-cli.mk
    ├── node-action.mk
    ├── node-lib.mk
    ├── docs-site.mk
    ├── markdown-lib.mk
    └── terraform.mk
```

## Usage

Add the submodule once:

```sh
git submodule add https://github.com/bitwise-media-group/make.git make
```

Then reduce the repo's `Makefile` to its archetype plus any per-repo knobs:

```makefile
# a Go CLI (dotty, evolve, gh-claude)
APP     := dotty
APP_PKG := ./cmd
include make/go-cli.mk

# docs is app-specific (regenerates the CLI reference), so it stays here and is
# appended to the pull-request gate:
docs: build ## regenerate the CLI reference and build the docs site
	@ ./$(APP) docs --out docs/cli --format markdown
	@ $(MAKE) docs-build
pr: docs
```

```makefile
# a Node Action (ff-merge, setup-evolve)
include make/node-action.mk
```

```makefile
# a Markdown/YAML library without a tools/go.mod (github-workflows, skills)
ADDLICENSE := go tool addlicense
include make/markdown-lib.mk
```

```makefile
# a Terraform environment (cloud-accounts/environments/<name>/)
include ../../make/terraform.mk
```

## The contract

The reusable CI workflow (`bitwise-media-group/github-workflows`) runs a matrix
of **`make lint`**, **`make build`**, **`make test`** (and opt-in **`make e2e`**);
release drives GoReleaser / Zensical directly. Every archetype provides those
canonical targets, plus **`fmt`**, **`ci`**, and **`pr`** for local use. Run
`make help` in any consuming repo to list what it exposes.

Canonical targets are **pure prerequisite aggregators** (no recipe), so a repo
extends them by adding prerequisites — `build: ui`, `pr: docs`, `lint: my-extra`
— without touching the library.

## Conventions the library assumes

- **License holder** is `BitWise Media Group Ltd` (override `LICENSE_HOLDER`).
- **addlicense** runs via `go tool -modfile=tools/go.mod addlicense`; repos whose
  tool directive lives in the root `go.mod` set `ADDLICENSE := go tool addlicense`.
- **npm prose scripts** are named `format`, `format:check`, `lint`, `lint:fix`
  (prettier + markdownlint). Node Actions add `check`, `check:fix`, `typecheck`,
  `build`, `test:coverage` (biome + rollup + vitest).
- **Overridable knobs** (`APP`, `APP_PKG`, `MODULE`, `TOOL`, `BUILD_TAGS`,
  `NPM_CI_FLAGS`, `TF_RUN`, …) are set in the repo `Makefile` *before* the
  `include`.

## Knobs by fragment

| Fragment | Key variables |
|---|---|
| `license.mk` | `LICENSE_HOLDER`, `ADDLICENSE`, `LICENSE_IGNORE` |
| `node.mk` | `NPM_CI_FLAGS` |
| `go.mk` | `APP`, `APP_PKG`, `MODULE`, `TOOL`, `VERSION`, `VERSION_PKG`, `LDFLAGS`, `BUILD_TAGS`, `FUZZ`, `FUZZ_PKG`, `FUZZTIME` |
| `terraform.mk` | `TERRAFORM_BINARY`, `TF_RUN` |
