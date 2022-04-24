## Project Requirements

#### A stateless application with frontend, backend and relational database

A demo stateless application taken from here, ```https://github.com/nimbella/demo-projects/tree/master/qrcode```. This will be connected to rdbms to store client information.

#### Terraform modules for deployment

Terraform modules to create single ec2 vm with docker, deploy application, turn it into ami, deploy ec2 autoscale group, alb or nlb to point to autoscale group, rds to store client info from backend, 2nd ec2 autoscale group to do b/g deployment.

#### Kubernetes deployment

Terraform modules to deploy eks or fargate cluster, rds to store client info from backend, deploy frontend to cloudfront if possible, deploy application backend, deploy istio for b/g deployment, loadbalancer to access.

## Project Architecture

## Setup Instructions