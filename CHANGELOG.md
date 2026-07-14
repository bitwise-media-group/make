# Changelog

## [2.1.2](https://github.com/bitwise-media-group/toolchain/compare/v2.1.1...v2.1.2) (2026-07-14)


### Bug Fixes

* **lint:** silence kubescape /dev/null.txt warning with --logger warning ([18402cb](https://github.com/bitwise-media-group/toolchain/commit/18402cb7e7c0b4d6777ef8aa3973f2f457444e09))

## [2.1.1](https://github.com/bitwise-media-group/toolchain/compare/v2.1.0...v2.1.1) (2026-07-14)


### Bug Fixes

* **deps:** update pinned tool versions ([2f08192](https://github.com/bitwise-media-group/toolchain/commit/2f08192e041c7dc5c60ae1cc1aa7b22f0000d978))

## [2.1.0](https://github.com/bitwise-media-group/toolchain/compare/v2.0.0...v2.1.0) (2026-07-14)


### Features

* lint docker/helm/kustomize/shell artifacts when present ([6a18943](https://github.com/bitwise-media-group/toolchain/commit/6a189436678e2c0a5abb48e78e3fe7b36584a951))


### Bug Fixes

* **tasks:** ignore commit.sh in the house license defaults ([247b20e](https://github.com/bitwise-media-group/toolchain/commit/247b20e25b44fc3c30040d608b496f68955c9caf))

## [2.0.0](https://github.com/bitwise-media-group/make/compare/v1.1.0...v2.0.0) (2026-07-10)


### ⚠ BREAKING CHANGES

* **tasks:** consumer Makefiles must remount the submodule at .mise/ (git mv make .mise + .gitmodules), replace `include make/<archetype>.mk` with `include .mise/mise.mk`, and add a root mise.toml declaring the archetype include and [vars]; fragments/ and the <archetype>.mk files no longer exist. The reusable CI workflow must gate its make matrix on task existence (mise tasks ls --name-only) before consumers migrate, since archetypes no longer stub absent targets. Repo-local prose configs become optional overrides of the house defaults shipped here.
* **tools:** consumers need mise on PATH (brew install mise); the per-repo <tool>_VERSION / <tool>_SHA pin overrides are gone (substitute a binary by setting its path variable, e.g. GOLANGCI_LINT := /path, before the include); go-test emits coverage/coverage.out instead of Cobertura XML; and fmt-prose/lint-prose run the mise-pinned prettier + markdownlint-cli2 directly instead of npm scripts -- repos whose package.json existed only for the prose linters can delete it (drop the format/format:check/lint/lint:fix scripts and the prettier/markdownlint-cli2 devDependencies everywhere else). Requires the github-workflows mise/coverage changes -- merge that repo first, then bump the reusable-workflow pins here.

### Features

* **tasks:** replace the Makefile fragment library with mise tasks ([fbc23d8](https://github.com/bitwise-media-group/make/commit/fbc23d85b4bc260341655e0be2dd4f533b6cebcf))
* **tools:** migrate tool pinning from .&lt;tool&gt;-version files to mise ([b2d10cc](https://github.com/bitwise-media-group/make/commit/b2d10cc9ea1b110ad980ea3d059f2d8771d5ade8))


### Bug Fixes

* **ci:** pin the mise binary hash, not the tarball hash ([440548f](https://github.com/bitwise-media-group/make/commit/440548f7e582ba6a8cb2032fcdb520a9d3f55a1b))

## [1.1.0](https://github.com/bitwise-media-group/make/compare/v1.0.0...v1.1.0) (2026-07-04)


### Features

* pin the evolve CLI as a shared go-tool ([112a748](https://github.com/bitwise-media-group/make/commit/112a748018f8b4c3979c15315511d1683a62b939))

## 1.0.0 (2026-07-04)


### Features

* add daily cooldown updater for go tool versions ([bb28e1d](https://github.com/bitwise-media-group/make/commit/bb28e1d97512ab3f13ca8b89f29fb9da836bf720))
* scaffold shared Makefile library for the ecosystem ([c30bc5b](https://github.com/bitwise-media-group/make/commit/c30bc5b7da3cb68815ff687ef981f6d68f1b6a8c))
* shared Makefile library with SHA-pinned go tooling ([fa70977](https://github.com/bitwise-media-group/make/commit/fa70977a07a693eff93ae071350a9a0f71925158))
