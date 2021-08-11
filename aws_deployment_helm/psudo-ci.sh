docker build -t kaldi-app .

sleep 2

docker tag kaldi-app:latest 669978739346.dkr.ecr.ap-southeast-1.amazonaws.com/kaldi-app:latest

sleep 1

docker push 669978739346.dkr.ecr.ap-southeast-1.amazonaws.com/kaldi-app:latest

sleep 3

kubectl scale --replicas=0 deployment/kaldi-test-master

sleep 3

helm upgrade kaldi-test helm/sgdecoding-online-scaled/

sleep 2

kubectl scale --replicas=0 deployment/kaldi-test-worker-singaporecs-0519nnet3

sleep 1