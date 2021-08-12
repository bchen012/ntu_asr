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
export GITLAB_PASSWORD=PASSWORD
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
kubectl create secret docker-registry regcred \
    --docker-server=registry.gitlab.com \
    --docker-username=$GITLAB_USERNAME \
    --docker-password=$GITLAB_PASSWORD \
    --docker-email=$GITLAB_EMAIL

helm install $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/
#helm upgrade $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/
#helm uninstall $KUBE_NAME


export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav


################
# set up Jenkins ci-cd
#################
kubectl apply -f jenkins-admin-service-account.yaml

cd Jenkins || exit

# Create a virtual machine using az vm create.
az vm create \
--resource-group $RESOURCE_GROUP \
--name Jenkins-vm \
--image UbuntuLTS \
--admin-username "azureuser" \
--generate-ssh-keys \
--custom-data cloud-init-jenkins.txt

# By default, Jenkins runs on port 8080. Therefore, open port 8080 on the new virtual machine using az vm open.
az vm open-port \
--resource-group $RESOURCE_GROUP \
--name Jenkins-vm  \
--port 8080 --priority 1010

# Open port 80 inbound.
az vm open-port \
--resource-group $RESOURCE_GROUP \
--name Jenkins-vm  \
--port 80 --priority 1020

# Get the public IP address for the sample virtual machine using az vm show.
az vm show \
--resource-group $RESOURCE_GROUP \
--name Jenkins-vm -d \
--query [publicIps] \
--output tsv

ssh azureuser@168.63.240.204

# Verify that Jenkins is running by getting the status of the Jenkins service.
service jenkins status

# install azure cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# login to azure account
az login

# Install Docker on jenkins-vm
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y;
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -;
sudo apt-key fingerprint 0EBFCD88;
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable";
sudo apt-get update;
sudo apt-get install docker-ce -y;

# Configure access
sudo usermod -aG docker jenkins;
sudo usermod -aG docker azureuser;
sudo touch /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion;
sudo service jenkins restart;
sudo chmod 777 /var/lib/jenkins/
sudo chmod 777 /var/lib/jenkins/config
sudo chmod 777 /var/run/docker.sock

# Get the autogenerated Jenkins password.
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# add container registry credentials
# add kubeconfig file
# configure github webhook
