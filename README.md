# Setting up ASR application on AZURE
1. Open terminal
2. Go to Project Directory
3. `cd Terraform_azure`
## Set up blob storage for Terraform backend
4. Log into azure console
5. Create a resource group named **terraform-group**
6. Create a storage account named **terraform-storage** in South East Asia
7. Create a storage container named **tfstate**
8. Go to **tfstate > Settings > Shared access tokens**
9. Create a SAS token with **Signing method = Account key**
10. Copy the SAS token generated
11. Go to **Terraform_azure/providers.tf** 
12. Fill up the following:<br />
`terraform { `<br />
`backend "azurerm" { `<br />
`resource_group_name = "terraform-group"`<br />
`storage_account_name = "terraform-storage"`<br />
`container_name = "tfstate"`<br />
`key = "prod.azure.tfstate"`<br />
`sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"`<br />
`}`<br />
`}`

## Set up Infrastructure using Terraform
13. Run `az login` so Terraform is authenticated with Azure
14. Run the following: <br/>
`terraform init` <br/>
`terraform validate` <br/>
`terraform plan` <br/>
`terraform apply` <br/>
15. Wait while Terraform configures your infrastructure
 
## Deploy ASR application
16. Run the following to set up Environment: <br />
`export GITLAB_USERNAME=GITLAB_USERNAME`<br />
`export GITLAB_PASSWORD=PASSWORD`<br />
`export GITLAB_EMAIL=GITLAB_EMAIL`<br />
`export KUBE_NAME=sgdecoding-online-scaled`<br />
`export RESOURCE_GROUP=ntu-online-scaled`<br />
`export STORAGE_ACCOUNT_NAME=ntuscaledstorage3`<br />
`export MODEL_SHARE=online-models`<br />
`export MODELS_FILESHARE_SECRET="models-files-secret"`<br />
`export STORAGE_KEY=$(az storage account keys list \`<br />
`--resource-group $RESOURCE_GROUP\`<br />
`--account-name $STORAGE_ACCOUNT_NAME \`<br />
`--query "[0].value" -o tsv)`<br />
`echo Storage account name: $STORAGE_ACCOUNT_NAME`<br />
`echo Storage account key: $STORAGE_KEY`<br /><br>
_Note: We are using Gitlab container Registry to store our container image_

17. 

# Setting up CI/CD using Jenkins




## References

setup jenkins on azure:
https://docs.microsoft.com/en-us/azure/developer/jenkins/configure-on-linux-vm
setup jenkins controller:
https://docs.microsoft.com/en-us/azure/developer/jenkins/deploy-from-github-to-aks#install-docker

creating kubeconfig:
http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
