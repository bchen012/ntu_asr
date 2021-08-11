cd Terraform_azure || exit
az login
terraform init --reconfigure\
    -backend-config="address=https://gitlab.com/api/v4/projects/27010974/terraform/state/production_azure" \
    -backend-config="username=benjaminc8121" \
    -backend-config="password=iEZo54NhdqGsaTe-4c_s"
terraform validate
terraform plan
terraform apply -auto-approve
cd ..


export GITLAB_USERNAME=benjaminc8121
export GITLAB_PASSWORD=0291012IpMs!
export GITLAB_EMAIL=benjaminc8121@gmail.com
export KUBE_NAME=sgdecoding-online-scaled
export RESOURCE_GROUP=ntu-online-scaled
export STORAGE_ACCOUNT_NAME=ntuscaledstorage3
export MODEL_SHARE=online-models
export MODELS_FILESHARE_SECRET="models-files-secret"
export STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
echo Storage account name: $STORAGE_ACCOUNT_NAME
echo Storage account key: $STORAGE_KEY



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


az aks get-credentials --resource-group $RESOURCE_GROUP --name asr-production --overwrite-existing
export NAMESPACE=ntuasr-production-azure
kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE
kubectl create secret generic $MODELS_FILESHARE_SECRET \
    --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY
kubectl apply -f azure_deployment_helm/secret/run_kubernetes_secret.yaml
kubectl apply -f azure_pv/
kubectl create secret docker-registry regcred --docker-server=registry.gitlab.com --docker-username=$GITLAB_USERNAME --docker-password=$GITLAB_PASSWORD --docker-email=$GITLAB_EMAIL
helm install $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/
#helm upgrade $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/
#helm uninstall $KUBE_NAME


export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav


################
# set up ci-cd
#################
# 1. connect aks to gitlab
kubectl cluster-info | grep -E 'Kubernetes master|Kubernetes control plane' | awk '/http/ {print $NF}'
kubectl get secret
kubectl get secret default-token-vchsc -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
kubectl apply -f gitlab-admin-service-account.yaml
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab | awk '{print $1}')


# 2. create service account
# az ad sp create-for-rbac --name TerraformServicePrincipal

# Output
#{
#  "appId": "34d68bab-ff56-4a58-b0ba-f1c6ebff22f0",
#  "displayName": "TerraformServicePrincipal",
#  "name": "http://TerraformServicePrincipal",
#  "password": "JLGvM2~Td8z8QVWT84-R9gCMvNOD3u0~kM",
#  "tenant": "15ce9348-be2a-462b-8fc0-e1765a9b204a"
#}


# 3. set up az credentials for terraform
#export ARM_CLIENT_ID=1a48ac87-4768-4ca2-887d-fe9327b1b37c
#export ARM_CLIENT_SECRET=z.~KIqlzG~Rhl9Xy3fAs71Xq3p3Sphbibv
#export ARM_SUBSCRIPTION_ID=1a04f332-b75e-492c-a57a-42bb0e830d49
#export ARM_TENANT_ID=79462702-9804-489b-9471-b17c34c68474

#These values map to the Terraform_azure variables like so:
#
#appId is the client_id defined above.
#password is the client_secret defined above.
#tenant is the tenant_id defined above.