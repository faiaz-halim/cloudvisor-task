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

### Deploy general terraform scripts

Provision vpc, rds, ec2 and corresponding subnets and security groups using,

```
make general-backend-dev
```

Update the ```tfdeploy/general/dev/versions.tf``` with s3 bucket, dynamodb and role arn from previous step. Plan and apply resources with following after updating ```tfdeploy/general/dev/terraform.tfvars```,

```
make general-init-plan-dev
make general-apply-dev
```

It will take some minutes to create rds and generate ami image,

Decommission using,

```
make general-destroy-dev
```

#### TODO: Manual steps automation (init db and docker container from terraform steps)

Ssh into the ec2 vm using ```ssh -i ~/.ssh/id_rsa.pem ubuntu@ec2_ip``` and connect to mysql from commandline. Run ```init.sql``` scripts create table command to generate db schema. Test application by running following and hit ec2 public dns from browser,

```
export HOST=db_host
export USER=db_user
export PASSWORD=db_user_pass
export DATABASE=db_name
sudo docker run -p 80:5000 -d --env HOST=$HOST --env USER=$USER --env PASSWORD=$PASSWORD --env DATABASE=$DATABASE --name nodeqr faiazhalim/node-qr-app:v0.01
```

Update: db initialize is still manual. Have to log into the 1st created ec2 and run this script at ```sudo /var/lib/cloud/instance/scripts/db.sh```. Test db integration with docker container ```sudo /var/lib/cloud/instance/scripts/run.sh```.

#### TODO: Run db init from ec2 startup script taking connection details from parameter store

Done

#### TODO: Setup ec2 autoscaling group with the custom ami made from modules

Done but not with custom AMI. Because custom AMI encrypted ebs volumes were giving trouble over kms keys. No time to troubleshoot it.

#### TODO: Implement similar setup for prod with hardened security and blue-green deployment