# make

Shared Makefiles for the bitwise-media-group ecosystem. Each repo consumes this library as a git submodule mounted at
`make/` (bumped by Dependabot's `gitsubmodule` ecosystem) and reduces its own `Makefile` to a few lines.

See [RECOMMENDATION.md](RECOMMENDATION.md) for the design rationale and the per-repo migration map.

## Layout

```text
make/
├── fragments/          # composable building blocks, one capability each
│   ├── common.mk       #   .DEFAULT_GOAL, help, commit, .NOTPARALLEL
│   ├── gotools.mk      #   go install pinned CLIs from .<tool>-version into .bin/
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
# a Markdown/YAML library (github-workflows, skills)
include make/markdown-lib.mk
```

```makefile
# a Terraform environment (cloud-accounts/environments/<name>/)
include ../../make/terraform.mk
```

## The contract

The reusable CI workflow (`bitwise-media-group/github-workflows`) runs a matrix of **`make lint`**, **`make build`**,
**`make test`** (and opt-in **`make e2e`**); release drives GoReleaser / Zensical directly. Every archetype provides
those canonical targets, plus **`fmt`**, **`ci`**, and **`pr`** for local use. Run `make help` in any consuming repo to
list what it exposes.

Canonical targets are **pure prerequisite aggregators** (no recipe), so a repo extends them by adding prerequisites —
`build: ui`, `pr: docs`, `lint: my-extra` — without touching the library.

## Go developer tools

The pinned Go CLIs (`addlicense`, `golangci-lint`, `govulncheck`, `gotestsum`, `gocover-cobertura`, `goreleaser`,
`syft`, `tflint`, `terraform-docs`, `actionlint`) are **not** vendored through a `tools/go.mod`. `go tool` management is
deliberately avoided — golangci-lint in particular breaks under it and its maintainers document that as unsupported.
Instead:

- each tool is pinned in a `.<tool>-version` file **at the root of this library** as `<version> <commit-sha>` — the
  readable tag plus the immutable git SHA it resolved to (`.golangci-lint-version` → `v2.12.2 c0d3ddc9…`), exactly as we
  pin GitHub Actions;
- `fragments/gotools.mk` `go install`s the tool **by SHA** (not the tag) into a repo-local `.bin/` the first time a
  target needs it, and reinstalls it when the pin changes. Pinning the SHA means a moved or re-pointed upstream tag
  cannot substitute different code; Go's checksum database verifies the fetch on top;
- bumping a tool for the **whole fleet** is one commit here (the daily updater below, or a hand-edit) + a submodule bump
  in the consumers.

A consuming repo therefore needs **zero** tool configuration. It can still pin a one-off version with
`golangci-lint_VERSION := v2.13.0` before the include.

Consuming repos should add `.bin/` (and `coverage/`) to `.gitignore`. The Go toolchain that runs `go install` comes from
the repo's own `go.mod` (Go products) or, for non-Go repos, from `make/.go-version` via the reusable CI's tooling
setup-go step.

Because the pins live in `.<tool>-version` files rather than a `go.mod`, Dependabot's gomod ecosystem no longer bumps
them. `.github/workflows/update-go-tools.yaml` replaces that: it runs `scripts/update-go-tools.sh` daily, which bumps
each pin (version **and** SHA) to the newest release that is at least 7 days old — a Dependabot-style cooldown — and
opens a single `fix(deps):` PR. Run it by hand with `./scripts/update-go-tools.sh` (or `--check` to just report).

## Other conventions the library assumes

- **License holder** is `BitWise Media Group Ltd` (override `LICENSE_HOLDER`).
- **npm prose scripts** are named `format`, `format:check`, `lint`, `lint:fix` (prettier + markdownlint). Node Actions
  add `check`, `check:fix`, `typecheck`, `build`, `test:coverage` (biome + rollup + vitest).
- **Overridable knobs** (`APP`, `APP_PKG`, `MODULE`, `BUILD_TAGS`, `NPM_CI_FLAGS`, `TF_RUN`, `TOOLS_BIN`,
  `<tool>_VERSION`, …) are set in the repo `Makefile` _before_ the `include`.

## Knobs by fragment

| Fragment       | Key variables                                                                                                 |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| `gotools.mk`   | `TOOLS_BIN`, `MK_ROOT`, `<tool>_VERSION` (e.g. `golangci-lint_VERSION`)                                       |
| `license.mk`   | `LICENSE_HOLDER`, `LICENSE_IGNORE`                                                                            |
| `node.mk`      | `NPM_CI_FLAGS`                                                                                                |
| `go.mk`        | `APP`, `APP_PKG`, `MODULE`, `VERSION`, `VERSION_PKG`, `LDFLAGS`, `BUILD_TAGS`, `FUZZ`, `FUZZ_PKG`, `FUZZTIME` |
| `terraform.mk` | `TERRAFORM_BINARY`, `TF_RUN`                                                                                  |
