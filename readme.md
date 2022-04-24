## Project Requirements

#### A stateless application with frontend, backend and relational database

A demo stateless application taken from here, ```https://github.com/franciskaguongo/Generate-a-QR-code-in-Node.js```. This will be connected to rdbms to store client information.

#### Terraform modules for deployment

Terraform modules to create single ec2 vm with docker, deploy application, turn it into ami, deploy ec2 autoscale group, alb or nlb to point to autoscale group, rds to store client info from backend, 2nd ec2 autoscale group to do b/g deployment.

#### Kubernetes deployment

Terraform modules to deploy eks or fargate cluster, rds to store client info from backend, deploy frontend to cloudfront if possible, deploy application backend, deploy istio for b/g deployment, loadbalancer to access.

## Project Architecture

## Setup Instructions

Copy ```.env_``` to ```.env``` and update necessary variable values.

### Build

Build docker image and push with following command,

```
make build
```

Build docker image with no cache and push,

```
make build-no-cache
```

### Run with docker

Run container temporarily with docker for local testing, (This assumes you already have accessible mysql server running somewhere and tables created. See ```src/init.sql``` for db provision instructions, replace ```db_user``` with your db user account)

```
make docker-run
```

Check logs with,

```
make docker-log
```

Delete temporary container,

```
make docker-delete
```

