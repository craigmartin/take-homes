# Kard take home project.

## Design Decisions
Decided to go with a simple two tier architecture for ease of review as well as minimal risk of complications to replicate.
I did include a 'Bastion' server in the public subnets, although functionality wise I decided to add AWS SSM function and no ssh security group rule and no included PEM files. My reasoning for doing this was to act on security best practices of limiting potential exposure of secrets as well as setting up for implementing POLP (principle of least priviledge).
Keeping with that in building and testing in my own workflow I used AWS IAM Identity Center to create a specific project user with timed AWS secret keys I utilized for the deployments.
I swayed from the instructions in the area of allowing SSH to a bastion and in designing for HA I added 4 subnets, 2 public and 2 private. The reasoning behind that is for HA I believe its useful to have a bastion in each of at least two azs and for the kard_app instance I believe the same is needed in at least 2 private subnets on 2 azs.
Additionally RDS requires 2 instances in order to provision, in this case 2 private instances.

## 
