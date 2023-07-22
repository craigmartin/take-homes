apply: plan
	terraform apply -var-file secrets.tfvars

plan: init
	terraform plan -var-file secrets.tfvars -out out.tfplan

init:
	terraform init
