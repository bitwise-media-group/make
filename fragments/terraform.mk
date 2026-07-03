# terraform.mk — plan/apply/lint/docs for a Terraform module.
# Generalises cloud-accounts/environments/cloud.mk.
ifndef MK_TERRAFORM_INCLUDED
MK_TERRAFORM_INCLUDED := 1

TERRAFORM_BINARY ?= terraform

# Wrapper that injects secrets/env around terraform (dotty env run). Set
# `TF_RUN :=` (empty) to call terraform directly.
TF_RUN ?= dotty env run --

.PHONY: tf-init init-no-backend plan apply tf-fmt tf-lint tf-docs
tf-init: ## initialise the terraform module
	@ $(TF_RUN) $(TERRAFORM_BINARY) init

# Backend-less init used by lint (validate needs an initialised module but no
# remote state); no `## ` so it stays out of `help`.
init-no-backend:
	@ $(TF_RUN) $(TERRAFORM_BINARY) init -backend=false -input=false

plan: ## plan infrastructure changes
	@ $(TF_RUN) $(TERRAFORM_BINARY) plan -out=plan.tfplan

apply: plan ## apply infrastructure changes
	@ $(TF_RUN) $(TERRAFORM_BINARY) apply plan.tfplan

# Auto-format pass wired into `fmt`.
tf-fmt:
	@ $(TERRAFORM_BINARY) fmt -recursive

# Check-mode pass wired into `lint`.
tf-lint: init-no-backend
	@ $(TERRAFORM_BINARY) validate .
	@ go tool tflint

# Doc generation wired into `docs`.
tf-docs:
	@ go tool terraform-docs .

endif
