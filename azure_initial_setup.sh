cd Terraform_azure || exit
az login
terraform init
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

# install helm in jenkins-vm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
sudo chmod 700 get_helm.sh
./get_helm.sh

# install terraform on jenkins-vm (ref https://learn.hashicorp.com/tutorials/terraform/install-cli)
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform


# install Kubernetes on jenkins-vm
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client


# install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version



# Get the autogenerated Jenkins password.
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# add container registry credentials, they can be used as env variables in pipeline
# add kubeconfig file, this can be used as env variable in pipeline: http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
kubectl create -f jenkins-admin-service-account.yaml
kubectl describe serviceAccounts jenkins -n kube-system
#output
#=====================================
#Name:                jenkins
#Namespace:           kube-system
#Labels:              <none>
#Annotations:         <none>
#Image pull secrets:  <none>
#Mountable secrets:   jenkins-token-rhkn6
#Tokens:              jenkins-token-rhkn6
#Events:              <none>
#======================================
kubectl describe secrets jenkins-token-8c2zg -n kube-system
#output
#============================
#Name:         jenkins-token-rhkn6
#Namespace:    kube-system
#Labels:       <none>
#Annotations:  kubernetes.io/service-account.name: jenkins
#              kubernetes.io/service-account.uid: 3d253598-7afa-4864-a2f1-ea50734c1e5a
#
#Type:  kubernetes.io/service-account-token
#
#Data
#====
#namespace:  11 bytes
#token:      eyJhbGciOiJSUzI1NiIsImtpZCI6Im01aWRLbktrWGd4all5Y04yXzJBTlkwbDZzc3dxMGlRS1Y2c251UkotR0UifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJqZW5raW5zLXRva2VuLXJoa242Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImplbmtpbnMiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIzZDI1MzU5OC03YWZhLTQ4NjQtYTJmMS1lYTUwNzM0YzFlNWEiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06amVua2lucyJ9.P3OPgeDVBNm3TcTWCZITQwIvIO2hj4TP2nmuGUni3zYE6aLQV0CfHqQma7L_hdfsOAxq6oyKLvLaK0AjjjncXO8JOtrX6A284Lic5P0XWnQ51OwetEU2oSf7zpeO7krdv-Vnk3vVdw70UXOxrhcZZR8cBpZTmA54LNx6aD2aP0LHrDza654wrcLOCP4UZwi_xHgZNyg98IB3TFOXcBfKOfHSz2Bp1lW0T-XiUn4CgnPAIGWz3BQrFCSIYL9yhhH4vtazLvd0zX-FAUhbBWuCoVUyWcOOAlq0_zyTwvcG87Kp6ZWitMt5Dc3QucPM-UJe8LRbpY1E83SW9q-0Jlwwb5g304vlS7i1GmgeExNE9BjwMztRKMn6BhK8XgkzzoqSGGmiAkYUJPhVRw8X7zK4feTV5ibD062aSXcyUHckr4u0G61Yng-gyc670j8wGn-AbIKO20R5b9Ti26BUWyQd3ng0W-FEF-uQk0wSebQj6XnQswih1tWOoYPMdOZ5_QgE0wzvNsuDJRNXKqn-SJErA63iZBpjNXIOyeqGKmMrzCSQm4vZ5m0eTxL3E7oRE6q0m55NbOQzS0ObC9faosBPxOzPlPUEGUPNHf1yY5p7B0-F53rxWXSH8Eu-irlG85yS_j1Hb85EtfGSoR2KjtVo3PSRNav3L4tJULvrJlOv9u4
#ca.crt:     1765 bytes
#===================================

kubectl config view --flatten --minify > cluster-cert.txt
cat cluster-cert.txt

# create kubeconfig file using kubeconfig_template at kubeconfig_files directory
# upload to jenkins as secret file


# configure github webhook, follow https://docs.microsoft.com/en-us/azure/developer/jenkins/deploy-from-github-to-aks#create-a-github-webhook


# create service account For Terraform Authentication

az ad sp create-for-rbac --name TerraformServicePrincipal

# Output
#{
#  "appId": "34d68bab-ff56-4a58-b0ba-f1c6ebff22f0",
#  "displayName": "TerraformServicePrincipal",
#  "name": "http://TerraformServicePrincipal",
#  "password": "JLGvM2~Td8z8QVWT84-R9gCMvNOD3u0~kM",
#  "tenant": "15ce9348-be2a-462b-8fc0-e1765a9b204a"
#}


# set up az credentials for terraform

#export ARM_CLIENT_ID=34d68bab-ff56-4a58-b0ba-f1c6ebff22f0
#export ARM_CLIENT_SECRET=trXJjEui35~inxFYHMC.uaGJJ368-6d-W-
#export ARM_SUBSCRIPTION_ID=1a04f332-b75e-492c-a57a-42bb0e830d49
#export ARM_TENANT_ID=15ce9348-be2a-462b-8fc0-e1765a9b204a

#appId is the client_id defined above.
#password is the client_secret defined above.
#tenant is the tenant_id defined above.


kubectl apply -f jenkins-admin-service-account.yaml


# build job - Credentials (REGISTRY_USER, REGISTRY_PASSWORD)

export IMAGE=registry.gitlab.com/benjaminc8121/ntu_asr/staging
docker login -u $REGISTRY_USER -p $REGISTRY_PASSWORD registry.gitlab.com
docker pull $IMAGE || true
docker build --cache-from $IMAGE:latest --tag $IMAGE:latest .
docker push $IMAGE:latest


# deploy infra job
#Credentials {
#export ARM_CLIENT_ID=34d68bab-ff56-4a58-b0ba-f1c6ebff22f0
#export ARM_CLIENT_SECRET=trXJjEui35~inxFYHMC.uaGJJ368-6d-W-
#export ARM_SUBSCRIPTION_ID=4768039f-ecfa-4781-8776-8acc2279e029
#export ARM_TENANT_ID=15ce9348-be2a-462b-8fc0-e1765a9b204a
#}

cd Terraform_azure
terraform init
terraform validate
terraform plan
terraform apply -auto-approve

# deploy application job - Credentials {KUBECONFIG}

export KUBE_NAME=sgdecoding-online-scaled
helm upgrade $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/ -n ntuasr-production-azure

# test job - Credentials {KUBECONFIG}

cd Jenkins-test
export KUBE_NAME=sgdecoding-online-scaled
export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc -n ntuasr-production-azure $MASTER_SERVICE --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $MASTER_SERVICE_IP
docker-compose up
