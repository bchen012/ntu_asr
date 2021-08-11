#!/usr/bin/env bash

usage() {
    cat <<EOF

Sending Multiple Jobs via websocket for decoding
----------------------------------------------------------------------------------------------------------------------------------------
Aim of the this script is to run multiple jobs simultaneously to see if the server is able to handle
the load (test if load balancing working?)
----------------------------------------------------------------------------------------------------------------------------------------

EOF
    1>&2
    exit 2
}

if [ "$1" == "--help" ]; then
    usage
fi

no_requests=$1

# change the IP address of the master service accordingly
# IP of the nginx controller: 20.43.160.52
# IP of the master service:  20.44.218.143
for i in {1..2}; do
  for j in $(seq 1 $no_requests); do
      NEW_UUID=`uuidgen`
      echo "#$i round: $j(th) request with output file output_$NEW_UUID.txt"
      python3 client_3_ssl.py -u ws://20.43.160.52/client/ws/speech \
          -r 32000 -t abc --model="English_0919_8k" \
          audio/20130919-channel1.wav 2>&1 | tee output/output_$NEW_UUID.txt &
      sleep 10
  done
  sleep 700
done

#exit 0
