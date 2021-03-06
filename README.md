# Set up ASR application on AZURE
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

## Set up Azure Infrastructure using Terraform
13. Run `az login` so Terraform is authenticated with Azure
14. Run the following in **Terraform_azure** directory: <br/>
```
terraform init
terraform validate
terraform plan
terraform apply
```
15. Wait while Terraform configures your infrastructure
 
## Deploy ASR application on Azure
16. Run the following to set up Environment: <br />
```
# For gitlab credentials, use mine because the ASR image is there
# You can build your own image and store it in your own account if you want, then just create a gitlab token with Read Registry access
export GITLAB_USERNAME=benjaminc8121
export GITLAB_PASSWORD=glpat-pa7YfxjHZxpTztcd8WHH
export GITLAB_EMAIL=benjaminc8121@gmail.com
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
kubectl create secret docker-registry regcred 
--docker-server=registry.gitlab.com 
--docker-username=$GITLAB_USERNAME 
--docker-password=$GITLAB_PASSWORD 
--docker-email=$GITLAB_EMAIL
```
25. Deploy application using Helm:
```
helm install $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/
```
26. Monitor Master and worker pods using:
```
kubectl get pods -w
```
27. Once the pods are running, test the application using:
```
export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav
```

# Set up ASR application on Google Cloud

## Set up Google Infrastructure using Terraform
1. Install Gcloud CLI
2. Run `gcloud auth application-default login` so Terraform is authenticated with Google Cloud
3. Go to Google Cloud console: https://console.cloud.google.com/
4. Create a project and copy the project ID
5. Set project to the project created
```
export PROJECT_ID=project-name-xxxxxx
gcloud config set project $PROJECT_ID
```
5. Enable APIs
```
gcloud services enable container.googleapis.com
gcloud services enable file.googleapis.com
```
6. Go to **Terraform_google/providers.tf** 
7. Fill up/replace the following:<br />
```
terraform { 
    backend "azurerm" { 
        resource_group_name = "terraform-group 
        storage_account_name = "terraform-storage 
        container_name = "tfstate 
        key = "prod.google.tfstate 
        sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX 
    }
}
```
_Note: We are same backend storage as Azure, just the key is different_

8. Run the following in **Terraform_google** directory: <br/>
```
terraform init
terraform validate
terraform plan
terraform apply
```
9. Wait while Terraform configures your infrastructure

## Deploy ASR application on Google Cloud

1. Upload model to Google File Store
 - Go to Gcloud console **Compute Engine > VM instances** and click one of the VMs
 - Get the code to ssh to the VM
 - ssh to the VM using a new terminal window
 - Run the following to mount the filestore onto the VM
``` 
 mkdir mnt 
 sudo mount <filstore ip>:/<filestore path> <mount directory>
 sudo chmod go+rw mnt
 pwd
```
 - Keep the output from the pwd command
 - Upload the models by running the following in our project root directory:
 ```
gcloud compute scp models/SingaporeCS_0519NNET3 <VM_ID>:<output_from_pwd> --project=<PROJECT_ID> --zone=asia-southeast1-a --recurse
gcloud compute scp models/SingaporeMandarin_0519NNET3 <VM_ID>:<output_from_pwd> --project=<PROJECT_ID> --zone=asia-southeast1-a --recurse
 ```
_Note: VM_ID looks something like this gke-gke-ntu-asr-clus-ntu-asr-node-poo-5a093a1f-fcd2_

2. Connect to Kubernetes Cluster on Google Cloud 
```
gcloud container clusters get-credentials gke-ntu-asr-cluster --zone asia-southeast1-a --project $PROJECT_ID
```
3. Run the following to set up Environment: <br />
```
export GITLAB_USERNAME=<GITLAB_USERNAME>
export GITLAB_PASSWORD=<PASSWORD>
export GITLAB_EMAIL=<GITLAB_EMAIL>
export KUBE_NAME=sgdecoding-online-scaled
export NAMESPACE=ntuasr-production-google
```
_Note: We are using Gitlab container Registry to store our container image_

4. Set up namespace for our application and go to that namespace: <br>
```
kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE
```
5. Apply Kubernetes secrets:
```
kubectl apply -f google_deployment_helm/secret/run_kubernetes_secret.yaml
```
6. Apply persistant volumes configurations:
```
kubectl apply -f google_pv/
```
7. Create Container Registry Credentials using Kubernetes secrets:
```
kubectl create secret docker-registry regcred 
--docker-server=registry.gitlab.com 
--docker-username=$GITLAB_USERNAME 
--docker-password=$GITLAB_PASSWORD 
--docker-email=$GITLAB_EMAIL
```
8. Deploy application using Helm:
```
helm install $KUBE_NAME google_deployment_helm/helm/sgdecoding-online-scaled/
```
9. Monitor Master and worker pods using:
```
kubectl get pods -w
```
10. Once the pods are running, test the application using:
```
export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav
```

# Set up ASR application on AWS
## Set up AWS Infrastructure using Terraform
1. Install AWS CLI and EKSCTL
2. Run `aws configure` to login to AWS
3. Fill in Credentials
4. Go to **Terraform_aws/vpc.tf** 
5. Fill up/replace the following:<br />
```
terraform { 
    backend "azurerm" { 
        resource_group_name = "terraform-group 
        storage_account_name = "terraform-storage 
        container_name = "tfstate 
        key = "prod.aws.tfstate 
        sas_token = "sp=racwdl&st=2021-08-29T07:35:55Z&se=2021-12-31T15:35:55Z&sv=2020-08-04&sr=c&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX 
    }
}
```
_Note: We are same backend storage as Azure, just the key is different_

6. Run the following in **Terraform_google** directory: <br/>
```
terraform init
terraform validate
terraform plan
terraform apply
```
7. Wait while Terraform configures your infrastructure

## Deploy ASR application on AWS
1. Upload models to EFS
 - Create a Key pair on AWS console
 - Create a new public subnet within the same VPC as the EFS
 - Launch an EC2 instance (micro will do) within the subnet we created
 - Mount the file system onto the EC2 instance
 - Include the Key pair we created in the EC2 instance
 - Run `scp -i "<Key_pair.pem>" -r models/ ec2-user@ec2-13-212-123-143.ap-southeast-1.compute.amazonaws.com:/mnt/efs/fs1` in project root directory
 - Wait for models to be uploaded
2. Run the following to set up Environment: <br />
```
export GITLAB_USERNAME=<GITLAB_USERNAME>
export GITLAB_PASSWORD=<PASSWORD>
export GITLAB_EMAIL=<GITLAB_EMAIL>
export KUBE_NAME=sgdecoding-online-scaled
export NAMESPACE=ntuasr-production-aws
export CLUSTERNAME=asr_cluster
```
_Note: We are using Gitlab container Registry to store our container image_

3. Create an IAM OIDC identity provider for your cluster: <br />
`eksctl utils associate-iam-oidc-provider --cluster $CLUSTERNAME --approve`
4. Connect to K8 Cluster: <br />
`aws eks --region ap-southeast-1 update-kubeconfig --name $CLUSTERNAME`
5. Create and set namespace <br />
```
kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE
```
6. deploy the EFS driver <br />
```
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set image.repository=602401143452.dkr.ecr.ap-southeast-1.amazonaws.com/eks/aws-efs-csi-driver \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa
```
7. Apply Kubernetes secrets:
```
kubectl apply -f aws_deployment_helm/secret/run_kubernetes_secret.yaml
```
8. Apply persistant volumes configurations:
```
kubectl apply -f aws_pv/
```
9. Create Container Registry Credentials using Kubernetes secrets:
```
kubectl create secret docker-registry regcred 
--docker-server=registry.gitlab.com 
--docker-username=$GITLAB_USERNAME 
--docker-password=$GITLAB_PASSWORD 
--docker-email=$GITLAB_EMAIL
```
10. Deploy application using Helm:
```
helm install $KUBE_NAME aws_deployment_helm/helm/sgdecoding-online-scaled/
```
11. Monitor Master and worker pods using:
```
kubectl get pods -w
```
12. Once the pods are running, test the application using:
```
export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav
```

# Setting up CI/CD using Jenkins

## Set up Jenkins VM
1. Go to Jenkins directory in Project:
`cd Jenkins`
1. Create Jenkins VM:
```
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name Jenkins-vm \
  --image UbuntuLTS \
  --admin-username "azureuser" \
  --generate-ssh-keys \
  --custom-data cloud-init-jenkins.txt
```
3. By default, Jenkins runs on port 8080. Therefore, open port 8080 on the new virtual machine using az vm open
```
az vm open-port \
  --resource-group $RESOURCE_GROUP \
  --name Jenkins-vm  \
  --port 8080 --priority 1010
```
4. Open port 80 inbound.
```
az vm open-port \
  --resource-group $RESOURCE_GROUP \
  --name Jenkins-vm  \
  --port 80 --priority 1020
```
5. Get the public IP address for the sample virtual machine using az vm show.
```
az vm show \
  --resource-group $RESOURCE_GROUP \
  --name Jenkins-vm -d \
  --query [publicIps] \
  --output tsv
```
6. Connect to the VM:
```
ssh azureuser@<ip-address-of-VM>
```
7. Verify that Jenkins is running by getting the status of the Jenkins service (Sometimes must wait a while):
```
service jenkins status
```
8. Install Azure CLI in Jenkins VM:
```
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```
9. Log into azure account in Jenkins VM:
```
az login
```
10. Install Docker on Jenkins VM:
```
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y;
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -;
sudo apt-key fingerprint 0EBFCD88;
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable";
sudo apt-get update;
sudo apt-get install docker-ce -y;
```
11. Configure access for Jenkins VM:
```
sudo usermod -aG docker jenkins;
sudo usermod -aG docker azureuser;
sudo touch /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion;
sudo service jenkins restart;
sudo chmod 777 /var/lib/jenkins/
sudo chmod 777 /var/lib/jenkins/config
sudo chmod 777 /var/run/docker.sock
```
12. Install helm in Jenkins VM:
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
sudo chmod 700 get_helm.sh
./get_helm.sh
```
13. Install terraform on Jenkins VM:
```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
```
14. Install Kubernetes on Jenkins VM:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```
15. Install docker-compose on Jenkins VM:
```
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

16. Get the autogenerated Jenkins password:
```
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
17. Using the public IP address of the Jenkins VM, open the following URL in a browser: http://<ip_address>:8080
18. Enter the password you retrieved earlier and select Continue
19. Select **Select plug-in to install**
20. Search for **Github** and check the box and click **Install**
21. Set up Credentials for Admin account and click **Save and Continue**
22. Click **Save and Finish > Start using Jenkins**
23. Jenkins is ready for use.

## Create Container Registry Secret for Jenkins
_This Secret will be used by our pipelines later on_
1. Go to **Dashboard > Manage Jenkins > Manage Credentials > (global) > Add Credentials**
2. **Kind** set to **Username with password**
3. Set Username to Gitlab username
4. Set Password to Gitlab Password
5. **ID** set to CR_Credentials
_Note: This is assuming that ASR Image is stored in your Gitlab Container Registry_

# Configure Azure CI/CD Pipeline

## Automate Azure Terraform Authentication
1. create service account For Terraform Authentication
```
az ad sp create-for-rbac --name TerraformServicePrincipal
```
_Output looks something like this_:
```
{
  "appId": "<appID>",
  "displayName": "TerraformServicePrincipal",
  "name": "http://TerraformServicePrincipal",
  "password": "<password>",
  "tenant": "<tenantID>"
}
```
2. Go to **Jenkins Dashboard > Manage Jenkins > Manage Credentials > Jenkins > Global credentials (unrestricted) > Add Credentials**
3. Create the following Credentials of type **Secret Text**:

 - **ID** - ARM_CLIENT_ID, **Secret** - appID (Get from output above)
 - **ID** - ARM_CLIENT_SECRET, **Secret** - password (Get from output above)
 - **ID** - ARM_SUBSCRIPTION_ID, **Secret** - subscriptio_ID (Get from Azure Console)
 - **ID** - ARM_TENANT_ID, **Secret** - tenantID (Get from output above)
    
## Create KUBECONFIG FILE
1. Follow this guide on how to create Kubeconfig Files: http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
2. Save the Kubeconfig file under **kubeconfig_files** Directory
3. Upload the Kubeconfig file to Jenkins as Secrets:
 - Go to **Dashboard > Manage Jenkins > Manage Credentials > (global) > Add Credentials**
 - **Kind** set to **Secret file**
 - Choose the Kubeconfig file we created
 - **ID**: Azure-Kubeconfig

## Configure Build Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'Azure-build' > Freestyle project**
3. Check **GitHub project** under **General** and paste the url of the project (e.g https://github.com/bchen012/ntu_asr/)
4. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
5. Check **GitHub hook trigger for GITScm polling** under **Build Triggers**
6. Check **Use secret text(s) or file(s)** under **Build Environment**
7. Set **Username Variable** to `REGISTRY_USER`
8. Set **Password Variable** to `REGISTRY_PASSWORD`
9. Select the CR_Credentials we created earlier
10. In **Build** section, add **Execute shell** to it
11. Add the following code to the command: <br />
```
export IMAGE=registry.gitlab.com/benjaminc8121/ntu_asr/staging
docker login -u $REGISTRY_USER -p $REGISTRY_PASSWORD registry.gitlab.com
docker pull $IMAGE || true
docker build --cache-from $IMAGE:latest --tag $IMAGE:latest .
docker push $IMAGE:latest
```
    
## Configure Deploy Infrastructure Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'Azure-Deploy-Infrastructure' > Freestyle project**
3. Select **Git** under **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **Azure-build** for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add the following secret texts to the build environment: <br />
 - **ID** - ARM_CLIENT_ID, **Secret** - appID (Get from output above)
 - **ID** - ARM_CLIENT_SECRET, **Secret** - password (Get from output above)
 - **ID** - ARM_SUBSCRIPTION_ID, **Secret** - subscriptio_ID (Get from Azure Console)
 - **ID** - ARM_TENANT_ID, **Secret** - tenantID (Get from output above)
_Note: These were created in one of the previous sections_<br />
**_Important: Variable names for each secret must be same as their ID_**
7. In **Build** section, add **Execute shell** to it
8. Add the following code to the command: <br />
```
cd Terraform_azure
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

## Configure Deploy Application Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'Azure-Deploy-ASR-Application' > Freestyle project**
3. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **Azure-Deploy-Infrastructure* for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add Secret file
7. Select the Kubeconfig file created earlier from the Azure cluster
8. Variable name set as `KUBECONFIG`
9. In **Build** section, add **Execute shell** to it
10. Add the following code to the command: <br />
```
export KUBE_NAME=sgdecoding-online-scaled
helm upgrade $KUBE_NAME azure_deployment_helm/helm/sgdecoding-online-scaled/ -n ntuasr-production-azure
```
    
# Configure Google Cloud CI/CD Pipeline
## Automate Google Cloud Terraform Authentication
1. Go to **IAM & Admin > ServiceAccounts > terraform-sa(created using terraform) > Keys** on Google Cloud Console
2. Create a new JSON type key
3. Save the Service account credentials file somewhere
4. Upload Credentials file as Secret file on Jenkins:
 - Go to **Dashboard > Manage Jenkins > Manage Credentials > (global) > Add Credentials**
 - **Kind** set to **Secret file**
 - Choose the Credentials file we saved
 - **ID**: Google-Credentials
5. Create Terraform role by running the following in **Terraform_google** directory: <br />
```
 gcloud iam roles create Terraform_role \
  --file=Terraform_role.yaml \
  --project $PROJECT_ID
```
6. Bind Terraform role to Service account created earlier: <br />
```
gcloud projects add-iam-policy-binding ntu-asr-317615 \
    --member=serviceAccount:<Client_email> \
    --role=projects/<project ID>/roles/Terraform_role
```
_Note: Client_email is found in the Credentials file_

## Create KUBECONFIG FILE
1. Follow this guide on how to create Kubeconfig Files: http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
2. Save the Kubeconfig file under **kubeconfig_files** Directory
3. Upload the Kubeconfig file to Jenkins as Secrets:
 - Go to **Dashboard > Manage Jenkins > Manage Credentials > (global) > Add Credentials**
 - **Kind** set to **Secret file**
 - Choose the Kubeconfig file we created
 - **ID**: Google-Kubeconfig

## Configure Build Job
_Only one build job is required as the clusters share one Container Registry_
_This was already configured on Azure's Pipeline_
    
## Configure Deploy Infrastructure Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'Google-Deploy-Infrastructure' > Freestyle project**
3. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **Azure-build** for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add a secret file
7. Select **Google-Credentials** file that we uploaded to Jenkins earlier
8. Set Variable to **GOOGLE_APPLICATION_CREDENTIALS**, other variable will not work
9. In **Build** section, add **Execute shell** to it
10. Add the following code to the command: <br />
```
cd Terraform_google
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

## Configure Deploy Application Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'Google-Deploy-ASR-Application' > Freestyle project**
3. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **Google-Deploy-Infrastructure* for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add Secret file
7. Select the Kubeconfig file created earlier from the Google cluster
8. Variable name set as `KUBECONFIG`
9. In **Build** section, add **Execute shell** to it
10. Add the following code to the command: <br />
```
export KUBE_NAME=sgdecoding-online-scaled
helm upgrade $KUBE_NAME google_deployment_helm/helm/sgdecoding-online-scaled/ -n ntuasr-production-google
```
 
## Configure Test Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'Google-Deploy-ASR-Application' > Freestyle project**
3. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **Google-Deploy-ASR-Application* for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add Secret file
7. Select the Kubeconfig file created earlier from the Google cluster
8. Variable name set as `KUBECONFIG`
9. In **Build** section, add **Execute shell** to it
10. Add the following code to the command: <br />
```
cd Jenkins-test
export KUBE_NAME=sgdecoding-online-scaled
export MASTER_SERVICE="$KUBE_NAME-master"
export MASTER_SERVICE_IP=$(kubectl get svc -n ntuasr-production-google $MASTER_SERVICE --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $MASTER_SERVICE_IP
docker-compose up
```

# Configure AWS CI/CD Pipeline
## Automate AWS Terraform Authentication
1. Go to **Jenkins Dashboard > Manage Jenkins > Manage Credentials > Jenkins > Global credentials (unrestricted) > Add Credentials**
2. Create the following Credentials of type **Secret Text**:
 - **ID** - AWS_ACCESS_KEY_ID, **Secret** - XXXXXXXXEXAMPLE
 - **ID** - AWS_SECRET_ACCESS_KEY, **Secret** - XXXXXX/XXXXXX/XXXXXEXAMPLEKEY

## Create KUBECONFIG FILE
1. Follow this guide on how to create Kubeconfig Files: http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
2. Save the Kubeconfig file under **kubeconfig_files** Directory
3. Upload the Kubeconfig file to Jenkins as Secrets:
 - Go to **Dashboard > Manage Jenkins > Manage Credentials > (global) > Add Credentials**
 - **Kind** set to **Secret file**
 - Choose the Kubeconfig file we created
 - **ID**: AWS-Kubeconfig


## Configure Build Job
_Only one build job is required as the clusters share one Container Registry_
_This was already configured on Azure's Pipeline_
    
## Configure Deploy Infrastructure Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'AWS-Deploy-Infrastructure' > Freestyle project**
3. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **Azure-build** for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add the following secret texts to the build environment: <br />
 - **ID** - AWS_ACCESS_KEY_ID, **Secret** - XXXXXXXXEXAMPLE
 - **ID** - AWS_SECRET_ACCESS_KEY, **Secret** - XXXXXX/XXXXXX/XXXXXEXAMPLEKEY
_Note: These were created in one of the previous sections_<br />
**_Important: Variable names for each secret must be same as their ID_**
7. In **Build** section, add **Execute shell** to it
8. Add the following code to the command: <br />
```
cd Terraform_AWS
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

## Configure Deploy Application Job
1. Log into Jenkins
2. Go to **Dashboard > New Item > Enter 'AWS-Deploy-ASR-Application' > Freestyle project**
3. Select **Git** uner **Source Code Management** and paste the Repository URL (e.g https://github.com/bchen012/ntu_asr.git) <br />
_Note: If the git Repo is private, create a access token and use that as the password when creating the secret credentials on Jenkins_
4. Under **Build Triggers** check **Build after other projects are built** and choose **AWS-Deploy-Infrastructure* for Projects to watch
5. Under **Build Environment** check **Use secret text(s) or file(s)**
6. Add Secret file
7. Select the Kubeconfig file created earlier from the AWS cluster
8. Variable name set as `KUBECONFIG`
9. In **Build** section, add **Execute shell** to it
10. Add the following code to the command: <br />
```
export KUBE_NAME=sgdecoding-online-scaled
helm upgrade $KUBE_NAME aws_deployment_helm/helm/sgdecoding-online-scaled/ -n ntuasr-production-aws
```
 
## References

Setup jenkins VM on Azure:
https://docs.microsoft.com/en-us/azure/developer/jenkins/configure-on-linux-vm
setup jenkins controller:
https://docs.microsoft.com/en-us/azure/developer/jenkins/deploy-from-github-to-aks#install-docker

creating kubeconfig:
http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/
