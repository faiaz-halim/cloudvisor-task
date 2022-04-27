include .env

build-image:
	docker build -t ${img}:${tag} ./src --no-cache

build-image-cache:
	docker build -t ${img}:${tag} ./src

push:
	docker push ${img}:${tag}

build: build-image-cache push

build-no-cache: build-image push

docker-run: 
	docker run -p 5000:5000 -d --env HOST=${HOST} --env USER=${USER} --env PASSWORD=${PASSWORD} --env DATABASE=${DATABASE} --name ${container_name} $(img):$(tag)

docker-log:
	docker logs -f ${container_name}

docker-delete:
	docker container rm -f ${container_name}

set-aws-creds-dev:
	export AWS_ACCESS_KEY_ID=${aws_access_key_id}
	export AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
	export AWS_DEFAULT_REGION=${aws_dev_region}

set-aws-creds-prod:
	export AWS_ACCESS_KEY_ID=${aws_access_key_id}
	export AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
	export AWS_DEFAULT_REGION=${aws_prod_region}

general-backend-dev:
	cd tfdeploy/general/dev/backend && terraform init && terraform plan && terraform apply --auto-approve

general-init-plan-dev:
	cd tfdeploy/general/dev && terraform init && terraform plan

general-apply-dev:
	cd tfdeploy/general/dev && terraform apply --auto-approve

general-refresh-dev:
	cd tfdeploy/general/dev && terraform apply -refresh-only -auto-approve

general-destroy-dev:
	cd tfdeploy/general/dev && terraform destroy --auto-approve

eks-init-plan-dev:
	cd tfdeploy/eks/dev && terraform init && terraform plan

eks-apply-dev:
	cd tfdeploy/eks/dev && terraform apply --auto-approve

eks-refresh-dev:
	cd tfdeploy/eks/dev && terraform apply -refresh-only -auto-approve

eks-destroy-dev:
	cd tfdeploy/eks/dev && terraform destroy --auto-approve

general-backend-prod:
	cd tfdeploy/general/prod/backend && terraform init && terraform plan && terraform apply --auto-approve

general-init-plan-prod:
	cd tfdeploy/general/prod && terraform init && terraform plan

general-apply-prod:
	cd tfdeploy/general/prod && terraform apply --auto-approve

general-destroy-prod:
	cd tfdeploy/general/prod && terraform destroy --auto-approve