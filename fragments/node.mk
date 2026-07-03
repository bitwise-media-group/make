# node.mk — the node_modules sentinel plus prose format/lint helpers.
ifndef MK_NODE_INCLUDED
MK_NODE_INCLUDED := 1

# Install the pinned Node tools exactly as locked in package-lock.json, and run
# them straight from node_modules (never npx or a global). --ignore-scripts is
# the safe default for repos that only use node for the doc linters; Node Action
# repos that need lifecycle scripts set `NPM_CI_FLAGS :=` before the include.
NPM_CI_FLAGS ?= --ignore-scripts --no-fund

# Sentinel target: re-runs npm ci only when package.json / the lockfile change.
node_modules: package.json package-lock.json
	@ npm ci $(NPM_CI_FLAGS)
	@ touch node_modules

# Prose format/lint via the repo's npm scripts. The ecosystem convention is
# prettier + markdownlint behind these four script names:
#   format / format:check / lint / lint:fix
.PHONY: fmt-prose lint-prose
fmt-prose: node_modules
	@ npm run lint:fix
	@ npm run format

lint-prose: node_modules
	@ npm run lint
	@ npm run format:check

endif
