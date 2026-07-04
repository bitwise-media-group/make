# terraform.mk — archetype for a Terraform module (cloud-accounts environments,
# safe-settings).
#
# Usage (per-environment Makefile). Because the module sits below the repo root,
# point the include at the submodule via a relative path, e.g. two levels down:
#     include ../../make/terraform.mk
#
# cloud-accounts keeps its root fan-out aggregator (environments/<name> recursion)
# unchanged; only the leaf environment Makefiles adopt this archetype.
ifndef MK_TERRAFORM_ARCHETYPE_INCLUDED
MK_TERRAFORM_ARCHETYPE_INCLUDED := 1

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MK_DIR)fragments/common.mk
include $(MK_DIR)fragments/gotools.mk
include $(MK_DIR)fragments/terraform.mk

.PHONY: init fmt lint docs ci pr
init: tf-init            ## initialise the terraform module
fmt:  tf-fmt             ## terraform fmt -recursive
lint: tf-lint            ## terraform validate + tflint
docs: tf-docs            ## generate module docs (terraform-docs)
ci:   lint docs          ## the checks the reusable CI workflow runs
pr:   fmt lint docs       ## full local gate before a pull request

# plan / apply come from terraform.mk.

endif
