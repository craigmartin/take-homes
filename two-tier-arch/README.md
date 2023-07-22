# Kard take home project.

## Design Decisions
Decided to go with a simple two tier architecture for code simplicity, ease of review, as well as minimal risk of complications to replicate.

I did include a 'Bastion' server in the public subnets, although functionality wise I decided to add AWS SSM function and no ssh security group rule and no included PEM files.
  My reasoning for doing this was to act on security best practices of limiting potential exposure of secrets as well as setting up for implementing POLP (principle of least priviledge).
Keeping with that principle, in building and testing in my own workflow I used AWS IAM Identity Center to create a specific project user with timed AWS secret keys I utilized for the deployments.

I swayed from the instructions in the areas of allowing SSH to a bastion and in designing for HA I added 4 subnets, 2 public and 2 private. 
  The reasoning behind that is for HA I believe its useful to have a bastion in each of at least two azs and for the kard_app instance I believe the same is needed in at least 2 private subnets on 2 azs.
Additionally RDS requires 2 instances in order to provision, in this case 2 private instances.

In reference to commodities/products used, I began coding attempting to utilize AWS CodeCatalyst with Cloud9 with the goal of showing (PoC) the practice of a centralized development environment integrated with built-in build system and CI.(first time using those tools) This proved to be a bit over engineered for this project leading to a more simplified approach. I will provide access to the workspace for this experiment but it is not what I view as part of the deliverable at this time. 

AWS SSM was utilized for the non SSH access to the bastion hosts. As a trade-off/potential improvement, SSM requires (at least to my knowledge) access to port 443 in the security group of the instances in question. The work-around for this which I would do with more time is to implement VPC endpoints and assign/utilize them for 'direct' ssm access to all of the ec2 instances.

## Trade-offs and Improvements
The proir statemet for adding VPC endpoints.
I would want to include Terragrunt for multi-environment configuration and Terratest for adding unit, integration, and E2E testing framework.
In my non-simple approach I was using Terraform modules in my directory layout, that would certainly be something I would do in real-world practice.

## Usage / Implementation
Assumptions:
AWS configuration is already setup.
Either Local tfstate is being used or another backend is setup to handle terrform state (eg s3 with dynamodb)

I will provide the file secrets.tfvar which contains the rds db_username and db_password values, they are not in source control as is best practice.
You will need to export those value and call the secrets.tfvar file with your apply command, which is already added to the Makefile so this is one terraform runs after the first if an apply run has already been saved eg.

You can run the terraform calls individually, or you can simply run:
$ make

I will add a screen recording of a network connectivity annalyzer I ran which you can mimic in AWS. And you can test bastion access via SSM through the AWS console ec2 instance details by clicking the Connect button at top left of screen.
Then click Session Manager tab and connect.
Terminal will access as ssm-user, you can run sudo su to switch to ec2-user.
$ sudo su - ec2-user

