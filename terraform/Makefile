.DEFAULT_GOAL: help
SHELL := /bin/bash

PROJECTNAME := "digital-ocean-k8s-challenge"

.PHONY: help
all: help
help: Makefile
	@echo
	@echo " Choose a command to run in "$(PROJECTNAME)":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo

.PHONY: create-cluster
## create-cluster: create a digital ocean cluster using terraform
create-cluster: tf-init tf-apply

.PHONY: tf-init
## tf-init: terraform init inside the `terraform` dir
tf-init:
	@terraform init -reconfigure

.PHONY: tf-apply
## tf-apply: terraform apply inside the `terraform` dir
tf-apply:
	@terraform apply

.PHONY: destroy-cluster
## destroy-cluster: destroy a digital ocean cluster created using terraform
destroy-cluster:
	@terraform destroy

.PHONY: get-kubeconfig
## get-kubeconfig:  get the kubeconfig value to a file from tf output
get-kubeconfig:
	@terraform output kubeconfig > secrets/kubeconfig
