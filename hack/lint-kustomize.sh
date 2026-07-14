#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# kubescape scan of every kustomization directory in the repo (kubescape
# builds the kustomization natively). kind: Component directories are only
# buildable through an overlay that includes them, so they are skipped with a
# note — the overlays that consume them still exercise their content. Repos
# silence accepted findings with a .kubescape/exceptions.json (auto-loaded
# here, the .grype.yaml spirit). KUBECONFIG points at nothing: kubescape
# otherwise contacts whatever cluster the developer's kubeconfig names, and a
# lint of local files must never touch a live cluster. --logger warning: at
# info level kubescape points its UI printer at /dev/null, appends .txt, and
# warns on every run when /dev/null.txt cannot be created; warning level swaps
# in the silent printer and avoids it (results still print via the results
# printer).
set -eu

: "${KUBESCAPE_SEVERITY:=high}"
export KUBECONFIG=/nonexistent

kubescape_scan() {
  if [ -f .kubescape/exceptions.json ]; then
    kubescape scan "$1" --logger warning --severity-threshold "$KUBESCAPE_SEVERITY" --exceptions .kubescape/exceptions.json
  else
    kubescape scan "$1" --logger warning --severity-threshold "$KUBESCAPE_SEVERITY"
  fi
}

find . \( -name .git -o -name .mise -o -name .claude -o -name node_modules -o -name .venv -o -name coverage \) -prune \
  -o \( -name kustomization.yaml -o -name kustomization.yml \) -print | sort | while IFS= read -r f; do
  d="${f%/*}"
  d="${d#./}"
  if grep -qE '^kind:[[:space:]]*Component([[:space:]]|$)' "$f"; then
    echo "lint-kustomize: skipping $d (kind: Component, only buildable via an overlay)"
    continue
  fi
  echo "lint-kustomize: kubescape scan $d"
  kubescape_scan "$d"
done
