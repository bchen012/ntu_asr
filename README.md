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
```
terraform { 
    backend "azurerm" { 
        resource_group_name = "terraform-group 
        storage_account_name = "terraform-storage 
        container_name = "tfstate 
        key = "prod.azure.tfstate 
        sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX 
    }
}
```

## Set up Infrastructure using Terraform
13. Run `az login` so Terraform is authenticated with Azure
14. Run the following: <br/>
```
terraform init
terraform validate
terraform plan
terraform apply
```
15. Wait while Terraform configures your infrastructure
 
## Deploy ASR application
16. Run the following to set up Environment: <br />
```
export GITLAB_USERNAME=GITLAB_USERNAME
export GITLAB_PASSWORD=PASSWORD
export GITLAB_EMAIL=GITLAB_EMAIL
export KUBE_NAME=sgdecoding-online-scaled
export NAMESPACE=ntuasr-production-azure
export RESOURCE_GROUP=ntu-online-scaled
export STORAGE_ACCOUNT_NAME=ntuscaledstorage3
export MODEL_SHARE=online-models
export MODELS_FILESHARE_SECRET="models-files-secret"
export STORAGE_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP\
  --account-name $STORAGE_ACCOUNT_NAME \
  --query "[0].value" -o tsv)
echo Storage account name: $STORAGE_ACCOUNT_NAME
echo Storage account key: $STORAGE_KEY<br>
```
_Note: We are using Gitlab container Registry to store our container image_

17. Download all the files this link and save it in **models/** directory: <br>
 https://www.dropbox.com/sh/fnfknblof219ngl/AAAHOPxQJ2FOK6Av1XQSj--Qa?dl=0 <br><br>
 _Note: Ensure the the directory structure is the same_
 
18. Upload the models onto Azure file store using the following command: <br>
```
NUM_MODELS=$(find ./models/ -maxdepth 1 -type d | wc -l)
if [ $NUM_MODELS -gt 1 ]; then
    echo "Uploading models to storage..."
    # az storage blob upload-batch -d $AZURE_CONTAINER_NAME --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME -s models/
    az storage file upload-batch -d $MODEL_SHARE --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME -s models/
else
    printf "\n"
    printf "##########################################################################\n"
    echo "Please put at least one model in the ./models directory before continuing"
    printf "##########################################################################\n"
    exit 1
fi
echo "$((NUM_MODELS - 1)) models uploaded to Azure File Share storage | Azure Files: $MODEL_SHARE"
```

19. Connect to the Kubernetes cluster by running: <br>
`az aks get-credentials --resource-group $RESOURCE_GROUP --name asr-production --overwrite-existing`
20. Set up namespace for our application and go to that namespace: <br>
```
kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE
```
21. Create Fileshare secret for cluster:
```
kubectl create secret generic $MODELS_FILESHARE_SECRET \
    --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY
```
22. Apply Kubernetes secrets:
```
kubectl apply -f azure_deployment_helm/secret/run_kubernetes_secret.yaml
```
23. Apply persistant volumes configurations:
```
kubectl apply -f azure_pv/
```
24. Create Container Registry Credentials using Kubernetes secrets:
```
kubectl create secret generic $MODELS_FILESHARE_SECRET \
    --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY
```
25. Deploy application using Helm:
```
helm install $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/
```

# Setting up CI/CD using Jenkins




## References

setup jenkins on azure:
https://docs.microsoft.com/en-us/azure/developer/jenkins/configure-on-linux-vm
setup jenkins controller:
https://docs.microsoft.com/en-us/azure/developer/jenkins/deploy-from-github-to-aks#install-docker

creating kubeconfig:
http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
