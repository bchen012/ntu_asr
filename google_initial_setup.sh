gcloud auth application-default login
# create project in google cloud console
export PROJECT_ID=ntu-asr-317615

# copy project id to provider project field
gcloud config set project $PROJECT_ID
gcloud services enable container.googleapis.com
gcloud services enable file.googleapis.com

# Terraform will set up application resources
cd Terraform_google || exit
terraform init
terraform validate
terraform plan
terraform apply -auto-approve

gcloud iam roles create Terraform_role \
--file=Terraform_role.yaml \
--project $PROJECT_ID

#gcloud iam roles update Terraform_role \
#--file=Terraform_role.yaml \
#--project $PROJECT_ID

gcloud projects add-iam-policy-binding ntu-asr-317615 \
    --member='serviceAccount:terraform-sa@ntu-asr-317615.iam.gserviceaccount.com' \
    --role='projects/ntu-asr-317615/roles/Terraform_role'
cd ..

export GITLAB_USERNAME=benjaminc8121
export GITLAB_PASSWORD=<PASSWORD>
export GITLAB_EMAIL=benjaminc8121@gmail.com
export KUBE_NAME=sgdecoding-online-scaled







# ssh into one of the vm
# mount the filestore onto vm

# mkdir mnt
# sudo mount <filstore ip>:/<filestore path> <mount directory>
# example: sudo mount 10.70.137.66:/modelshare mnt
# sudo chmod go+rw mnt
# pwd # must use the full path of the mount directory for scp command


# upload models onto mount directory from local computer

# gcloud compute scp models/SingaporeCS_0519NNET3 gke-gke-ntu-asr-clus-ntu-asr-node-poo-5a093a1f-fcd2:/home/ONG/mnt --project=ntu-asr-317615 --zone=asia-southeast1-a --recurse
# gcloud compute scp models/SingaporeMandarin_0519NNET3 gke-gke-ntu-asr-clus-ntu-asr-node-poo-5a093a1f-fcd2:/home/ONG/mnt --project=ntu-asr-317615 --zone=asia-southeast1-a --recurse


gcloud container clusters get-credentials gke-ntu-asr-cluster --zone asia-southeast1-a --project $PROJECT_ID
export NAMESPACE=ntuasr-staging-google
kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE
kubectl apply -f google_deployment_helm/secret/run_kubernetes_secret.yaml
kubectl apply -f google_pv/
kubectl create secret docker-registry regcred --docker-server=registry.gitlab.com --docker-username=$GITLAB_USERNAME --docker-password=$GITLAB_PASSWORD --docker-email=$GITLAB_EMAIL
helm install $KUBE_NAME google_deployment_helm/helm/sgdecoding-online-scaled/

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
kubectl get secret default-token-dgpp6 -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
kubectl apply -f gitlab-admin-service-account.yaml
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab | awk '{print $1}')


