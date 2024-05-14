#!/bin/bash
set -e

#SLURM_TAG=${SLURM_TAG:-slurm-23-02-7-1} #Frontier ver - WIP
SLURM_TAG=${SLURM_TAG:-slurm-21-08-6-1}

IMAGE=${IMAGE:-slurm-docker-cluster-cuda}
IMAGE_TAG=${IMAGE_TAG:-21.08}

# Export all just in case
set -a

case $1 in

build)
    docker build --build-arg SLURM_TAG=${SLURM_TAG} -t ${IMAGE}:${IMAGE_TAG} .
;;

clean)
    docker compose stop
    docker compose rm -f
    docker volume rm slurm-docker-cluster-cuda_etc_munge slurm-docker-cluster-cuda_etc_slurm  \
        slurm-docker-cluster-cuda_var_lib_mysql slurm-docker-cluster-cuda_var_log_slurm
;;

up)
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

# Shell in a fresh base image
shell)
    docker run --rm -it --entrypoint /bin/bash ${IMAGE}:${IMAGE_TAG}
;;

esac