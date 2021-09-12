cd Terraform_aws || exit
aws configure

#file_system_id=$(aws efs create-file-system \
#    --region ap-southeast-1 \
#    --performance-mode generalPurpose \
#    --query 'FileSystemId' \
#    --output text)

terraform init
terraform validate
terraform plan
terraform apply -auto-approve
cd ..


#upload model#
#scp -i "bens-key-pair.pem" -r models ec2-user@ec2-13-212-123-143.ap-southeast-1.compute.amazonaws.com:/mnt/efs/fs1
#ssh -i "bens-key-pair.pem" ec2-user@ec2-18-141-181-181.ap-southeast-1.compute.amazonaws.com


export GITLAB_USERNAME=benjaminc8121
export GITLAB_PASSWORD=PASSWORD
export GITLAB_EMAIL=benjaminc8121@gmail.com
export KUBE_NAME=sgdecoding-online-scaled
export NAMESPACE=ntuasr-production-aws
export CLUSTERNAME=asr_cluster

# To create an IAM OIDC identity provider for your cluster
eksctl utils associate-iam-oidc-provider --cluster $CLUSTERNAME --approve

# Connect to K8 Cluster
aws eks --region ap-southeast-1 update-kubeconfig --name $CLUSTERNAME

# Create and set namespace
kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE


# deploy the EFS driver
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set image.repository=602401143452.dkr.ecr.ap-southeast-1.amazonaws.com/eks/aws-efs-csi-driver \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa


kubectl apply -f aws_pv/

kubectl create secret docker-registry regcred \
    --docker-server=registry.gitlab.com \
    --docker-username=$GITLAB_USERNAME \
    --docker-password=$GITLAB_PASSWORD \
    --docker-email=$GITLAB_EMAIL

kubectl apply -f aws_deployment_helm/secret/run_kubernetes_secret.yaml

helm install $KUBE_NAME aws_deployment_helm/helm/sgdecoding-online-scaled/
#helm upgrade $KUBE_NAME aws_deployment_helm/helm/sgdecoding-online-scaled/
#helm uninstall $KUBE_NAME

# test
export URL=a4d2a16214605401c8bf5a2d9f31f07c-1283009693.ap-southeast-1.elb.amazonaws.com:80
python3 client/client_3_ssl.py -u ws://$URL/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav
python3 client/client_3_ssl.py -u ws://$URL/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav

curl  -X PUT -T client/audio/episode-1-introduction-and-origins.wav --header "model: SingaporeCS_0519NNET3" --header "content-type: audio/x-wav" "http://$URL/client/dynamic/recognize"

################
# set up ci-cd
#################
# 1. connect aks to gitlab
kubectl cluster-info | grep -E 'Kubernetes master|Kubernetes control plane' | awk '/http/ {print $NF}'
kubectl get secret
kubectl get secret default-token-cqdql -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
kubectl apply -f jenkins-admin-service-account.yaml
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep jenkins | awk '{print $1}')
