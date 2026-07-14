#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# helm lint + kubescape misconfiguration scan for every chart under helm/
# (one chart per directory: helm/*/Chart.yaml). kubescape renders helm charts
# natively with their default values. No charts → silent no-op. Repos silence
# accepted findings with a .kubescape/exceptions.json (auto-loaded here, the
# .grype.yaml spirit). KUBECONFIG points at nothing: kubescape otherwise
# contacts whatever cluster the developer's kubeconfig names, and a lint of
# local files must never touch a live cluster. --logger warning: at info level
# kubescape points its UI printer at /dev/null, appends .txt, and warns on
# every run when /dev/null.txt cannot be created; warning level swaps in the
# silent printer and avoids it (results still print via the results printer).
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

for chart in helm/*/Chart.yaml; do
  [ -f "$chart" ] || continue
  d="${chart%/Chart.yaml}"
  echo "lint-helm: helm lint $d"
  helm lint "$d"
  echo "lint-helm: kubescape scan $d"
  kubescape_scan "$d"
done
