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