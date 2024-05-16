#!/bin/bash
set -e

# Figure out where we really are
OUR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$OUR_DIR"

#SLURM_TAG=${SLURM_TAG:-slurm-23-02-7-1} #Frontier ver - WIP
SLURM_TAG=${SLURM_TAG:-slurm-21-08-6-1}

IMAGE=${IMAGE:-slurm-docker-cluster-cuda}
IMAGE_TAG=${IMAGE_TAG:-21.08}

# Export all just in case
set -a

case $1 in

build)
    docker build --progress=plain --build-arg SLURM_TAG=${SLURM_TAG} -t ${IMAGE}:${IMAGE_TAG} .
;;

clean)
    docker compose stop
    docker compose rm -f
    docker volume rm slurm-docker-cluster-cuda_etc_munge slurm-docker-cluster-cuda_etc_slurm  \
        slurm-docker-cluster-cuda_var_lib_mysql slurm-docker-cluster-cuda_var_log_slurm
;;

down)
    docker compose down
;;

run|up)
    docker compose up
;;

# Shell on control node
ctl)
    docker exec -it slurmctld bash
;;

# Just run something on the "cluster"
# In this configuration jobs need to be submitted via the control node/container
r)
    shift
    docker exec -it slurmctld srun "$@"
;;

# Shell on c1 AKA c
c|c1)
    docker exec -it c1 bash
;;

# Shell on c2
c2)
    docker exec -it c2 bash
;;

# You should never need this, just in case...
register)
    docker exec slurmctld bash -c "/usr/bin/sacctmgr --immediate add cluster name=linux" && \
    docker compose restart slurmdbd slurmctld
;;

# Shell in a fresh base image
shell)
    docker run --gpus=all --rm -it -v ${PWD}:/local --entrypoint /bin/bash ${IMAGE}:${IMAGE_TAG}
;;

*)
    echo "Passing to docker compose"...
    shift
    docker compose "$@"
;;

esac