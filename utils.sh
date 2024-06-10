#!/bin/bash
set -e

# Figure out where we really are
OUR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$OUR_DIR"

# Used during docker build
CUDA_VER=${CUDA_VER:-12.1.0}
ROCM_VER=${ROCM_VER:-5.7.1}

CONDA_PATH=${CONDA_PATH:-/local/mgpu/conda}
PYTHON_VER=${PYTHON_VER:-3.10}

#SLURM_TAG=${SLURM_TAG:-slurm-23-02-7-1} #Frontier ver - WIP
SLURM_TAG=${SLURM_TAG:-slurm-21-08-6-1}

IMAGE=${IMAGE:-slurm-docker-cluster-gpu}
IMAGE_TAG=${IMAGE_TAG:-21.08}

detect_hw() {
    # Default to no GPU (cpu)
    GPU="cpu"

    if [ -c /dev/kfd ]; then
        GPU="rocm"
    fi

    if [ -c /dev/nvidia0 ]; then
        GPU="cuda"
    fi
}

get_hw_info_cmd() {
    GPU_INFO="echo No GPU Found"

    if [ -x /usr/bin/nvidia-smi ]; then
        GPU_INFO="/usr/bin/nvidia-smi"
    fi

    if [ -x /usr/bin/rocm-smi ]; then
        GPU_INFO="/usr/bin/rocm-smi"
    fi
}

get_num_gpus() {
    # Assume 0
    GPU_COUNT=0

    if [ "$GPU" = "cuda" ]; then
        GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv | grep -v name | wc -l)
        echo "Detected $GPU_COUNT Nvidia GPU(s)"
    fi

    if [ "$GPU" = "rocm" ]; then
        GPU_COUNT=$(rocm-smi -a --csv | grep card | wc -l)
        echo "Detected $GPU_COUNT AMD GPU(s)"
    fi
}

gen_config() {
    cp *.conf configs/
    if [ $GPU_COUNT = 0 ]; then
        echo "NodeName=c[1-2] RealMemory=48164 CPUs=32 Sockets=1 CoresPerSocket=16 ThreadsPerCore=2 State=UNKNOWN" >> configs/slurm.conf
    else
        if [ "$GPU" = "rocm" ]; then
            echo "# AMD" > configs/gres.conf
            echo "AutoDetect=rsmi" >> configs/gres.conf
        fi
        # TODO: Support NVML...
        if [ "$GPU" = "cuda" ]; then
            echo "# Nvidia" > configs/gres.conf
            for i in $(ls /dev/nvidia[0-7]); do
                echo "Name=gpu File=$i" >> configs/gres.conf
            done
        fi
    echo "GresTypes=gpu" >> configs/slurm.conf
    echo "NodeName=c[1-2] RealMemory=48164 CPUs=32 Sockets=1 CoresPerSocket=16 ThreadsPerCore=2 Gres=gpu:${GPU_COUNT} State=UNKNOWN" >> configs/slurm.conf
    fi
}

detect_hw
get_hw_info_cmd
get_num_gpus

# Export all just in case
set -a

case $1 in

build)
    gen_config
    docker build --progress=plain --build-arg SLURM_TAG=${SLURM_TAG} --build-arg CUDA_VER=${CUDA_VER} \
        --build-arg ROCM_VER=${ROCM_VER} --build-arg GPU=${GPU} \
        -f Dockerfile.${GPU} -t ${IMAGE}:${IMAGE_TAG} .

;;

conda-mgpu)
    rm -rf ${CONDA_PATH}
    conda create -y -p ${CONDA_PATH} python=${PYTHON_VER}
;;

clean)
    rm -f configs/*
    docker compose -f docker-compose-${GPU}.yml down
    docker compose -f docker-compose-${GPU}.yml rm -f
    docker volume rm slurm-docker-cluster-gpu_etc_munge slurm-docker-cluster-gpu_etc_slurm  \
        slurm-docker-cluster-gpu_var_lib_mysql slurm-docker-cluster-gpu_var_log_slurm
;;

config)
    gen_config
;;

down)
    docker compose -f docker-compose-${GPU}.yml down
;;

run|up)
    # Make sure we have .env
    touch .env
    docker compose -f docker-compose-${GPU}.yml up
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
    echo "GPU info:"
    ${GPU_INFO}
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
    docker compose -f docker-compose-${GPU}.yml "$@"
;;

esac