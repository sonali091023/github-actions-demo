CLUSTER  ?= skillpulse
NAMESPACE ?= skillpulse
BACKEND_IMAGE  ?= trainwithshubham/skillpulse-backend:latest
FRONTEND_IMAGE ?= trainwithshubham/skillpulse-frontend:latest

.PHONY: up down build load apply status logs mysql restart deploy-dev destroy-dev

up: ## One-shot: build images, create cluster, load images, apply manifests
	#Before deployment starts, Makefile checks k8s/kind-config.yaml exists, backend/ exists, frontend/ exists, k8s/ exists etc.
	@echo "==== VERIFYING PROJECT STRUCTURE ===="   
	@test -f k8s/kind-config.yaml || (echo "Missing k8s/kind-config.yaml" && exit 1)

	@test -d backend || (echo "Missing backend directory" && exit 1)

	@test -d frontend || (echo "Missing frontend directory" && exit 1)

	@test -d k8s || (echo "Missing k8s directory" && exit 1)
	
	$(MAKE) build
	
	@if ! kind get clusters | grep -wq $(CLUSTER); then \
		kind create cluster --config k8s/kind-config.yaml --name $(CLUSTER); \
	else \
		echo "Cluster $(CLUSTER) already exists"; \
	fi

	$(MAKE) load
	$(MAKE) apply
	@echo
	@echo "  SkillPulse is live at http://localhost:8888"
	@echo

build: ## Build backend + frontend images for the host's architecture
	docker build -t $(BACKEND_IMAGE)  ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend

load: ## Push built images into the kind node
	kind load docker-image $(BACKEND_IMAGE)  --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)

apply: ## Apply manifests and wait for rollouts
	kubectl apply -f k8s/00-namespace.yaml \
	              -f k8s/10-mysql.yaml \
	              -f k8s/20-backend.yaml \
	              -f k8s/30-frontend.yaml
	kubectl rollout status statefulset/mysql    -n $(NAMESPACE) --timeout=180s
	kubectl rollout status deployment/backend   -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/frontend  -n $(NAMESPACE) --timeout=60s

down: ## Delete the cluster
	kind delete cluster --name $(CLUSTER)

status: ## Quick health snapshot
	@kubectl get pods,svc,endpoints -n $(NAMESPACE)

logs: ## Tail all three workloads at once
	@kubectl logs -n $(NAMESPACE) -l 'app in (mysql,backend,frontend)' --all-containers --tail=50 -f --max-log-requests=10

mysql: ## Open a mysql shell into the StatefulSet pod
	kubectl exec -it -n $(NAMESPACE) mysql-0 -- mysql -uskillpulse -pskillpulse123 skillpulse

restart: ## Rebuild + reload images, roll backend + frontend
	$(MAKE) build
	$(MAKE) load
	kubectl rollout restart deployment/backend deployment/frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/backend  -n $(NAMESPACE) --timeout=120s
	kubectl rollout status  deployment/frontend -n $(NAMESPACE) --timeout=60s

deploy-dev:
	cd terraform/envs/dev && \
	terraform fmt -recursive && \
	terraform init -upgrade && \
	terraform validate && \
	terraform apply -auto-approve

destroy-dev:
	cd terraform/envs/dev && \
	terraform init -upgrade && \
	terraform destroy -auto-approve

