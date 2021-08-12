#!/bin/bash
set -u


export KUBE_NAME=sgdecoding-online-scaled
kubectl create secret docker-registry regcred --docker-server=registry.gitlab.com --docker-username=benjaminc8121 --docker-password=$PASSWORD --docker-email=benjaminc8121@gmail.com
kubectl apply -f google_deployment_helm/secret/run_kubernetes_secret.yaml
kubectl apply -f google_pv/kaldi-models-pv.yaml
kubectl apply -f google_pv/kaldi-models-pvc.yaml

kubectl config set-context --current --namespace $NAMESPACE

# installing tiller, part of helm installation
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

helm install $KUBE_NAME google_deployment_helm/helm/sgdecoding-online-scaled/

#helm upgrade $KUBE_NAME --namespace $NAMESPACE docker/helm/sgdecoding-online-scaled/
#helm uninstall $KUBE_NAME --namespace $NAMESPACE


################################################################################
########### Step 5: Install the dashboard with Grafana/Prometheus  #############

# Setup Prometheus and Grafana
# Method 1:
git clone https://github.com/prometheus-community/helm-charts.git prometheus-helm-charts

helm install prometheus \
    --set server.global.scrape_interval='10s' \
    --set server.global.scrape_timeout='10s' \
    --set server.persistentVolume.size='35Gi' \
    --set server.global.evaluation_interval='10s' \
    --namespace $NAMESPACE \
    prometheus-helm-charts/prometheus

# Method 2: (Recommended)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update

helm install prometheus prometheus-community/prometheus --namespace $NAMESPACE

# Take note on the Prometheus server address:
# NOTES:
# The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
# prometheus-server.monitoring.svc.cluster.local
#
# --------------------------------------
# echo "Waiting for Prometheus to be deployed within the cluster..."
# sleep 3
# export PROMETHEUS_POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
# echo "Prometheus is deployed on K8s!"

# INSTALL GRAFANA:
# Link: https://github.com/grafana/helm-charts
git clone https://github.com/grafana/helm-charts.git grafana-helm-chart

# CAREFULLY !!!
# Need to check values namespace and other parameters (list of models to monitor) in this file
#   kaldi-grafana-dashboard.json (model name)
git clone https://github.com/grafana/helm-charts.git grafana-helm-charts
cp monitoring/kaldi-grafana-dashboard.json grafana-helm-charts/charts/grafana/dashboards/kaldi-grafana-dashboard.json

# CAREFULLY !!!
# Need to check values namespace and other parameters in these files
#   grafana-config.yaml (namespace and URL from prometheus installation - see above installation of Prometheus)
#   grafana-values.yaml
kubectl apply -f monitoring/grafana-config.yaml
helm install -f monitoring/grafana-values.yaml \
      grafana \
    --namespace $NAMESPACE \
    --set persistence.enabled=true \
    --set persistence.accessModes={ReadWriteOnce} \
    --set persistence.size=5Gi \
    grafana-helm-charts/charts/grafana/
echo "Waiting for Grafana to be deployed within the cluster..."
sleep 10

export GRAFANA_ADMIN_PW=$(
   kubectl get secret --namespace $NAMESPACE grafana -o jsonpath="{.data.admin-password}" | base64 --decode
   echo
)

kubectl patch svc grafana \
     --namespace "$NAMESPACE" \
     -p '{"spec": {"type": "LoadBalancer"}}'


export MASTER_SERVICE="$KUBE_NAME-master"
export GRAFANA_SERVICE_IP=$(kubectl get svc grafana \
    --namespace $NAMESPACE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --namespace $NAMESPACE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat > cluster-info.txt <<EOF

KALDI SPEECH RECOGNITION SYSTEM deployed on Kubernetes
###################################################################

Access the Master pod service at http://$MASTER_SERVICE_IP

You may access the speech recognition function using a live microphone or by passing in an audio file.

For example,

python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav

OR

curl  -X PUT -T docker/audio/long/episode-1-introduction-and-origins.wav --header "model: SingaporeCS_0519NNET3" --header "content-type: audio/x-wav" "http://$MASTER_SERVICE_IP/client/dynamic/recognize"

###################################################################


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Grafana is deployed on K8s at http://$GRAFANA_SERVICE_IP

Login to Grafana dashboard with the following credentials,

User: admin
Password: $GRAFANA_ADMIN_PW

The custom Kaldi Speech Recognition Kubernetes dashboard is available in the General folder.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

EOF

echo -e "\e[32mAll information about the Kaldi Test Kubernetes cluster is available in cluster-info.txt in this directory! \e[0m"
# clean up Prometheus and Grafana helm files
rm -rf /tmp/pro-fana

exit 0
