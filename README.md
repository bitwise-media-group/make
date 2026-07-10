# toolchain

Shared build tasks for the bitwise-media-group ecosystem — pinned developer tools, mise task archetypes, and house
lint/license policy — with a thin Makefile shim on top. Each repo consumes this library as a git submodule mounted at
`.mise/` (bumped by Dependabot's `gitsubmodule` ecosystem) and reduces its own `Makefile` to one include and its own
mise config to a few lines. (Formerly named `make`, from its Makefile-fragment era; GitHub redirects the old URL.)

See [RECOMMENDATION.md](RECOMMENDATION.md) for the original design rationale and the per-repo migration map (its
Makefile-fragment mechanics are superseded by the mise-task layout described here).

## Layout

```text
toolchain/                # this repo == the consumer's .mise/ directory
├── config.toml           # shared config: [settings], [tools] pins, [vars] knob
│                         #   defaults, and the universal tasks (license, prose
│                         #   lint, commit, actionlint); consumers load it
│                         #   natively as .mise/config.toml
├── mise.lock              # per-platform sha256 + provenance for every pin
├── tasks/                 # one self-contained task file per archetype
│   ├── go-cli.toml        #   go build/test/lint/release + zensical docs
│   ├── node-action.toml   #   biome + tsc + rollup + vitest
│   ├── node-lib.toml      #   tsup build + type-check
│   ├── docs-site.toml     #   zensical build/serve
│   ├── markdown-lib.toml  #   prose + license only
│   └── terraform.toml     #   init/plan/apply + tf fmt/lint/docs
└── mise.mk                # the whole make surface: thin forwarders to mise
```

## Usage

Add the submodule once, mounted at `.mise/`:

```sh
git submodule add https://github.com/bitwise-media-group/toolchain.git .mise
```

Create a root `mise.toml` that picks the archetype and sets any knobs, then reduce the `Makefile` to one line:

```toml
# mise.toml — a Go CLI (dotty, evolve, gh-claude)
[vars]
app = "dotty"
app_pkg = "./cmd"

[task_config]
includes = [".mise/tasks/go-cli.toml"]

# repo-local tasks live here too, e.g. the app-specific CLI reference:
[tasks.docs]
description = "regenerate the CLI reference and build the docs site"
dir = "{{cwd}}"
run = ["mise run build", "./dotty docs --out docs/cli --format markdown", "mise run docs-build"]
```

```makefile
# Makefile — the whole thing
include .mise/mise.mk

# append repo-local work to a canonical gate (runs before `mise run pr`):
pr: docs
```

Run `mise trust --all` once per clone (CI trusts the workspace automatically), and `make help` (or `mise tasks`) to list
what the repo exposes. Because the Makefile only forwards, `make <anything>` and `mise run <anything>` are
interchangeable — the Makefile exists for the CI contract and muscle memory, and the pipelines can move to invoking mise
natively without touching this library.

## The contract

The reusable CI workflow (`bitwise-media-group/github-workflows`) runs a matrix of **`make lint`**, **`make build`**,
**`make test`** (and opt-in **`make e2e`**), discovering which of those tasks a repo actually defines via
`mise tasks ls --name-only` and skipping the rest; release drives GoReleaser / Zensical directly. There are therefore
**no no-op stubs anywhere**: an archetype defines only real work (markdown-lib has no `build`/`test` at all), and a repo
that grows tests or an e2e suite just defines that task in its root `mise.toml [tasks]`. Every archetype also provides
**`fmt`**, **`ci`**, and **`pr`** for local use.

Extension works both ways:

- **make-side** — add a prerequisite in the repo Makefile (`pr: docs`, `lint: my-extra`). Prerequisites run **before**
  the forwarded task (the old library ran appended targets after `commit`; if ordering matters more precisely, use the
  mise-side mechanism).
- **mise-side** — add new tasks in the repo's root `mise.toml [tasks]`. To **redefine** a task the archetype already
  defines, put it in a repo-local task file included _after_ the archetype (later includes win whole-task; an included
  file also beats the same config's own `[tasks]` on name collisions):

  ```toml
  [task_config]
  includes = [".mise/tasks/go-cli.toml", "tasks.toml"] # tasks.toml redefines e.g. fuzz or pr
  ```

Aggregates (`fmt`, `lint`, `ci`, `pr`) are sequential task composites, so mutating passes never race and `fmt` always
precedes `lint` inside `pr`.

## Developer tools

Every tool (`addlicense`, `golangci-lint`, `govulncheck`, `gotestsum`, `goreleaser`, `syft`, `terraform`, `tflint`,
`terraform-docs`, `actionlint`, `evolve`, `dotty`, `prettier`, `markdownlint-cli2`) is pinned in `config.toml` with
per-platform sha256 checksums (and, where the publisher provides it, cosign/SLSA/GitHub-attestation provenance) locked
in `mise.lock`. Tasks run with the pinned tools already on PATH — there is no `.bin/`, no `tools/go.mod`, no
`package.json` for linters, and no tool-path plumbing anywhere. mise installs a tool into its shared per-machine store
the first time a task needs it (verifying the checksum) and reuses it across every repo.

- The tooling runtimes themselves are pins (`go`, `node`), provisioned by mise — no system Go or Node is needed.
- Bumping a tool for the **whole fleet** is one commit here (the daily updater below, or a hand-edit of `config.toml` +
  `mise lock`) plus a submodule bump in the consumers.
- A repo can override a tool version (or add tools) in its root `mise.toml [tools]` — the root config wins.
- **Never run `mise lock` or `mise upgrade` in a consumer repo**: the lockfile lives in this library, so a consumer-side
  re-lock writes into the submodule working tree.

Consuming repos should keep `coverage/` (and `node_modules/`) in `.gitignore`; `.bin/` is no longer created.

Dependabot has no mise ecosystem, so `.github/workflows/update-tools.yaml` replaces it: it runs `mise upgrade --bump`
daily, which honours `minimum_release_age = "7d"` — a release must be at least 7 days old before it is adopted, a
Dependabot-style cooldown — re-locks the checksums with `mise lock`, and opens a single `fix(deps):` PR. Run it by hand
with `mise upgrade --bump && mise lock` in this directory (or `mise outdated` to just report).

## Knobs

Two tiers, replacing the old before-the-include make variables:

| tier                           | where                   | examples                                                                                         |
| ------------------------------ | ----------------------- | ------------------------------------------------------------------------------------------------ |
| structural (set once per repo) | root `mise.toml [vars]` | `app`, `app_pkg`, `build_tags`, `version_pkg`, `license_holder`, `tf_run`                        |
| per-invocation (runtime)       | environment variables   | `VERSION`, `COMMIT`, `DATE`, `LDFLAGS`, `MODULE`, `FUZZ`, `FUZZTIME`, `FUZZ_PKG`, `NPM_CI_FLAGS` |

`make build VERSION=1.2.3` still works — make exports command-line variables to the forwarded `mise run`, and the go-cli
scripts also accept the old spellings (`APP`, `APP_PKG`, …) from the environment.

## Other conventions the library assumes

- **License holder** is `BitWise Media Group Ltd` (override `license_holder` in `[vars]`). The license tasks ignore
  generated/vendored trees (`node_modules/`, `.mise/`, `.claude/`, `.venv/`, `coverage/`) by default; a repo's
  `.licenseignore` adds to that.
- **Prose is linted in every archetype, with zero per-repo config**: `fmt`/`lint` always run the pinned prettier +
  markdownlint-cli2 over all `*.md` from the repo root, excluding generated and vendored content (`CHANGELOG.md`,
  `node_modules/`, `.mise/`, `.venv/`, `.claude/`). The house defaults are this library's own `.prettierrc.yaml` /
  `.prettierignore` / `.markdownlint-cli2.yaml`, read from `.mise/` — a repo that commits its own copy of one of those
  files overrides that file wholesale. Node Action **npm scripts** are named `check`, `check:fix`, `typecheck`, `build`,
  `test:coverage` (biome + rollup + vitest); biome owns the code, prettier + markdownlint own the markdown.
- **This repo's own layout is inverted**: `config.toml` sits at the root (it _is_ the consumer's `.mise/`), the dogfood
  archetype include lives in the root `mise.toml`, and `.mise/` here contains symlinks back to the root files so mise
  resolves the tools the same way it does in a consumer.
