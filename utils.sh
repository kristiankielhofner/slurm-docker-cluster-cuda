#!/bin/bash
set -e

# Figure out where we really are
OUR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$OUR_DIR"

# Used during docker build
CUDA_VER=${CUDA_VER:-12.1.0}

# Used during docker build
ROCM_VER=${ROCM_VER:-5.7.1}

CONDA_PATH=${CONDA_PATH:-/local/mgpu/conda}
PYTHON_VER=${PYTHON_VER:-3.10}

#SLURM_TAG=${SLURM_TAG:-slurm-23-02-7-1} #Frontier ver - WIP
SLURM_TAG=${SLURM_TAG:-slurm-21-08-6-1}

IMAGE=${IMAGE:-slurm-docker-cluster-gpu}
IMAGE_TAG=${IMAGE_TAG:-21.08}

# Export all just in case
set -a

case $1 in

build)
    docker build --progress=plain --build-arg SLURM_TAG=${SLURM_TAG} --build-arg CUDA_VER=${CUDA_VER} \
        -t ${IMAGE}:${IMAGE_TAG} .
;;

conda-mgpu)
    rm -rf ${CONDA_PATH}
    conda create -y -p ${CONDA_PATH} python=${PYTHON_VER}
;;

clean)
    docker compose stop
    docker compose rm -f
    docker volume rm slurm-docker-cluster-gpu_etc_munge slurm-docker-cluster-gpu_etc_slurm  \
        slurm-docker-cluster-gpu_var_lib_mysql slurm-docker-cluster-gpu_var_log_slurm
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
dr)
    shift
    docker exec -it slurmctld srun "$@"
;;

# Shell on compute nodes
c*)
    docker exec -it $1 bash
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

info)
    echo "Hostname is $HOSTNAME"
    echo "Nvidia info"
    nvidia-smi
;;

# Job helpers
# Submit job
r)
    shift
    sbatch --export=NONE "$@"
;;

# List jobs
l)
    squeue
;;

# Debug job
d)
    shift
    scontrol show jobid -dd "$@"
;;

# Cancel job
k)
    shift
    scancel "$@"
;;

*)
    echo "Passing to docker compose"...
    shift
    docker compose "$@"
;;

esac