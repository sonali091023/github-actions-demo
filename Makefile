CLUSTER        ?= skillpulse
NAMESPACE      ?= skillpulse
BACKEND_IMAGE  ?= trainwithshubham/skillpulse-backend:latest
FRONTEND_IMAGE ?= trainwithshubham/skillpulse-frontend:latest
MYSQL_USER     ?= skillpulse
MYSQL_PASSWORD ?= skillpulse123
MYSQL_DATABASE ?= skillpulse

.PHONY: up down build load apply status logs mysql restart deploy-dev destroy-dev fmt help

.DEFAULT_GOAL := help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## One-shot: verify structure, build images, create cluster, load images, apply manifests
	@echo "==== VERIFYING PROJECT STRUCTURE ===="
	@test -f k8s/kind-config.yaml || (echo "ERROR: Missing k8s/kind-config.yaml" && exit 1)
	@test -d backend              || (echo "ERROR: Missing backend directory"      && exit 1)
	@test -d frontend             || (echo "ERROR: Missing frontend directory"     && exit 1)
	@test -d k8s                  || (echo "ERROR: Missing k8s directory"          && exit 1)
	$(MAKE) build
	$(MAKE) cluster
	$(MAKE) load
	$(MAKE) apply
	@echo
	@echo "  SkillPulse is live at http://localhost:8888"
	@echo

cluster: ## Create kind cluster if it does not already exist
	@if ! kind get clusters | grep -wq $(CLUSTER); then \
		kind create cluster --config k8s/kind-config.yaml --name $(CLUSTER); \
	else \
		echo "Cluster $(CLUSTER) already exists, skipping creation"; \
	fi

build: ## Build backend + frontend images for the host architecture
	docker build -t $(BACKEND_IMAGE)  ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend

load: ## Load built images into the kind cluster node
	kind load docker-image $(BACKEND_IMAGE)  --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)

apply: ## Apply Kubernetes manifests and wait for rollouts
	kubectl apply -f k8s/00-namespace.yaml \
	              -f k8s/10-mysql.yaml \
	              -f k8s/20-backend.yaml \
	              -f k8s/30-frontend.yaml
	kubectl rollout status statefulset/mysql   -n $(NAMESPACE) --timeout=180s
	kubectl rollout status deployment/backend  -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/frontend -n $(NAMESPACE) --timeout=60s

down: ## Delete the kind cluster
	kind delete cluster --name $(CLUSTER)

status: ## Quick health snapshot of pods, services, and endpoints
	@kubectl get pods,svc,endpoints -n $(NAMESPACE)

logs: ## Tail logs for mysql, backend, and frontend simultaneously
	@kubectl logs -n $(NAMESPACE) -l 'app in (mysql,backend,frontend)' \
	  --all-containers --tail=50 -f --max-log-requests=10

mysql: ## Open an interactive MySQL shell inside the StatefulSet pod
	kubectl exec -it -n $(NAMESPACE) mysql-0 -- \
	  mysql -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE)

restart: ## Rebuild + reload images, then rolling-restart backend and frontend
	$(MAKE) build
	$(MAKE) load
	kubectl rollout restart deployment/backend deployment/frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/backend  -n $(NAMESPACE) --timeout=120s
	kubectl rollout status  deployment/frontend -n $(NAMESPACE) --timeout=60s

fmt: ## Format all Terraform files (does not apply any changes)
	cd terraform/envs/dev && terraform fmt -recursive

deploy-dev: ## Terraform init + validate + apply for the dev environment
	cd terraform/envs/dev && \
	terraform init -upgrade && \
	terraform validate && \
	terraform apply -auto-approve

destroy-dev: ## Terraform destroy for the dev environment (prompts for confirmation)
	@echo "WARNING: This will PERMANENTLY destroy the dev environment."
	@read -p "Type 'yes' to confirm: " ans && [ "$$ans" = "yes" ] || \
	  (echo "Aborted." && exit 1)
	cd terraform/envs/dev && \
	terraform init -upgrade && \
	terraform destroy -auto-approve