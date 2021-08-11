#!/bin/bash

expected_jobs=$1

echo "Cleaning the completed job first"
/home/appuser/opt/kubectl delete job $(/home/appuser/opt/kubectl get job -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}')
echo "Finished cleaning."

#1. Check the number of workers available
NO_ENG_JOBS=$(/home/appuser/opt/kubectl get pods --field-selector=status.phase=Running | grep 'english-0919-8k' | wc -l)
NO_PENDING_JOBS=$(/home/appuser/opt/kubectl get pods --field-selector=status.phase=Pending | grep 'english-0919-8k' | wc -l)

echo "There are $NO_ENG_JOBS jobs running and $NO_PENDING_JOBS jobs pending."

#2. Call the spawn_worker till enough
export new_jobs="$((($expected_jobs - $NO_ENG_JOBS - $NO_PENDING_JOBS)/2 + 1))"

if [ $new_jobs -gt 0 ]  
then
    echo "Need to spawning $new_jobs new workers / jobs ..."
    #/home/appuser/opt/kubectl scale --replicas $expected_jobs deployment/sgdecoding-online-scaled-worker-english-0919-8k
fi

/home/appuser/opt/kubectl scale --replicas $expected_jobs deployment/sgdecoding-online-scaled-worker-english-0919-8k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-cs-09am-8k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-cs-10am-10lmv4-16k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-english-0919-8k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-english-10am-10lmv3-16k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-engmalay-0119nnet3-16k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-malay-0319nnet3-16k
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-mandarin-0519nnet3
#/home/appuser/opt/kubectl scale --replicas 0 deployment/sgdecoding-online-scaled-worker-mandarin-09am-8k


#echo "Cleaning the completed job first"
#/home/appuser/opt/kubectl delete job $(/home/appuser/opt/kubectl get job -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}')
#echo "Finished cleaning."

#if [ $new_jobs -gt 0 ]
#then
#    echo "Spawning..."

#    for i in $(seq 1 $new_jobs); do
#        python3 /home/appuser/opt/master_server_addon.py "English_0919_8k" >> /home/appuser/opt/creating_jobs.log  &
#        sleep 1
#    done
#fi

#/home/appuser/opt/kubectl delete job $(/home/appuser/opt/kubectl get job --namespace $NAMESPACE -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}') --namespace $NAMESPACE
