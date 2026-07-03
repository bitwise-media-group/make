# action.mk — build/test/lint for a Node/TypeScript GitHub Action.
#
# Convention (ff-merge, setup-evolve): biome for lint+format, tsc for types,
# rollup to bundle dist/, vitest for tests. Depends on node.mk for node_modules.
ifndef MK_ACTION_INCLUDED
MK_ACTION_INCLUDED := 1

.PHONY: action-fmt action-lint action-build action-test
# Auto-fix pass wired into `fmt`.
action-fmt: node_modules
	@ npm run check:fix
	@ npm run format

# Check-mode static analysis wired into `lint`: biome (lint + format check,
# incl. markdownlint) then the TypeScript type-check.
action-lint: node_modules
	@ npm run check
	@ npm run typecheck

# Bundle the action into dist/ with rollup. The reusable CI fails the PR if the
# committed dist/ then differs from source, so this must be reproducible.
action-build: node_modules
	@ npm run build

# vitest with coverage — emits coverage/cobertura-coverage.xml + coverage/junit.xml.
action-test: node_modules
	@ npm run test:coverage

endif
