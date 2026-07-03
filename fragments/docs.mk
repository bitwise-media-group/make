# docs.mk — Zensical documentation site (Python via uv).
ifndef MK_DOCS_INCLUDED
MK_DOCS_INCLUDED := 1

# `uv` provisions Python + zensical from pyproject.toml on first use. The built
# site/ is git-ignored. `sync` re-runs only when the Python manifests change.
sync: pyproject.toml uv.lock
	@ uv run sync

.PHONY: docs-build serve
docs-build: sync ## build the documentation site (zensical)
	@ uv run zensical build

serve: sync ## serve the docs site locally (zensical)
	@ uv run zensical serve

endif
