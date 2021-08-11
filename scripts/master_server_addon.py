# pylint: disable=import-error

import logging
import random
import string
import os
import sys

from kubernetes import client, config
from kubernetes.client.rest import ApiException


IMAGE = os.getenv("IMAGE", False)
MASTER = os.getenv("MASTER", False)
NAMESPACE = os.getenv("NAMESPACE", False)


if IMAGE == False or MASTER == False or NAMESPACE == False:
    sys.exit("No values for IMAGE="
             + str(IMAGE)
             + " MASTER="+str(MASTER)
             + " NAMESPACE="+str(NAMESPACE))

config.load_kube_config()


def spawn_worker(model):
    """
    Spawn a new worker with the model specified if all the workers are in use.
    Call this function before pop()
    Will not spawn new worker when running as docker-compose up, check 'master:8080'

    model : str
        The name of model
    """
    if MASTER == 'master:8080':
        return

    create_job(model)


def id_generator(size=6, chars=string.ascii_lowercase + string.digits):
    return ''.join(random.choice(chars) for _ in range(size))


def create_job(MODEL):
    assert MODEL is not None, "model name is None, cannot spawn a new worker"

    api = client.BatchV1Api()
    body = client.V1Job(api_version="batch/v1", kind="Job")
    name = 'speechlab-worker-job-{}-{}'.format(MODEL.lower().replace("_", "-"), id_generator())
    body.metadata = client.V1ObjectMeta(namespace=NAMESPACE, name=name)
    body.status = client.V1JobStatus()
    template = client.V1PodTemplate()
    template.template = client.V1PodTemplateSpec()
    template.template.metadata = client.V1ObjectMeta(
        annotations={
            "prometheus.io/scrape": "true",
            "prometheus.io/port": "8081"
        }
    )
    efs_volume_claim = client.V1PersistentVolumeClaimVolumeSource(
        claim_name='models-efs-claim'
    )
    volume = client.V1Volume(
        name='models-efs',
        persistent_volume_claim=efs_volume_claim
    )
    env_vars = {
        "MASTER": MASTER,
        "NAMESPACE": NAMESPACE,
        "RUN_FREQ": "ONCE",
        "MODEL_DIR": MODEL,
    }

    env_list = []
    if env_vars:
        for env_name, env_value in env_vars.items():
            env_list.append(client.V1EnvVar(name=env_name, value=env_value))

    container = client.V1Container(name='{}-c'.format(name),
                                   image=IMAGE,
                                   image_pull_policy="IfNotPresent",
                                   command=["/home/appuser/opt/tini", "--",
                                            "/home/appuser/opt/start_worker.sh"],
                                   env=env_list,
                                   ports=[client.V1ContainerPort(
                                       container_port=8081,
                                       name="prometheus"
                                   )],
                                   security_context=client.V1SecurityContext(
                                       privileged=True, capabilities=client.V1Capabilities(add=["SYS_ADMIN"])),
                                   resources=client.V1ResourceRequirements(
                                       limits={"memory": "6G", "cpu": "1"}, 
                                       requests={"memory": "5G", "cpu": "0.8"}
                                       ),
                                   volume_mounts=[client.V1VolumeMount(
                                        mount_path="/home/appuser/opt/models",
                                        name="models-efs",
                                        read_only=True
                                    )]
    )

    template.template.spec = client.V1PodSpec(containers=[container],
                                              # reason to use OnFailure https://github.com/kubernetes/kubernetes/issues/20255
                                              restart_policy="OnFailure",
                                              volumes=[volume]
                                              )

    # And finaly we can create our V1JobSpec!
    body.spec = client.V1JobSpec(
        ttl_seconds_after_finished=100, template=template.template)

    try:
        logging.info('trying to create job')
        api_response = api.create_namespaced_job(NAMESPACE, body)
        print("api_response="+ str(api_response))
        return True
    except ApiException as e:
        logging.exception('error spawning new job: ' + str(e))
        print("Exception when creating a job: %s\n" % e)


import threading
class SpawnWorker(threading.Thread):
    def __init__(self, model=None, *args, **kwargs):
        super(SpawnWorker, self).__init__(*args, **kwargs)
        self.model = model

    def run(self):
        spawn_worker(self.model)
        print("Spawn another worker from outside of master_server.py")


import sys
if __name__ == "__main__":
    model = sys.argv[1]
    SpawnWorker(model=model).start()
