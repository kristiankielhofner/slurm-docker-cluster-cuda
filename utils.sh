#!/usr/bin/env bash
set -e
set -a

# Figure out where we really are
OUR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$OUR_DIR"

if [ -s .env ]; then
    echo "Using .env for configuration"
    . .env
fi

# Used during docker build
CUDA_VER=${CUDA_VER:-12.1.0}
ROCM_VER=${ROCM_VER:-5.7.1}

CONDA_PATH=${CONDA_PATH:-/local/mgpu/conda}
MINICONDA_VER=${MINICONDA_VER:-23.11.0-0} # Version on Frontier as of 6/10/2024
PYTHON_VER=${PYTHON_VER:-3.10}

SLURM_VER=${SLURM_VER:-23.02.7} # Version on Frontier as of 6/10/2024
IMAGE=${IMAGE:-slurm-docker-cluster-gpu}
IMAGE_TAG=${IMAGE_TAG:-${SLURM_VER}}

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
    CPU_COUNT=$(nproc)
    # This is gross and prone to breakage
    # WIP: Hard-code for now
    #AVAIL_MEM=$(free -m | grep Mem | cut -d" " -f12)
    AVAIL_MEM=${AVAIL_MEM:-8192}
    if [ $GPU_COUNT = 0 ]; then
        echo "NodeName=c[1-2] RealMemory=${AVAIL_MEM} CPUs=${CPU_COUNT} State=UNKNOWN" >> configs/slurm.conf
    else
        if [ "$GPU" = "rocm" ]; then
            echo "# AMD" > configs/gres.conf
            echo "AutoDetect=rsmi" >> configs/gres.conf
        fi
        if [ "$GPU" = "cuda" ]; then
            echo "# Nvidia" > configs/gres.conf
            echo "AutoDetect=nvml" >> configs/gres.conf
        fi
        echo "GresTypes=gpu" >> configs/slurm.conf
        echo "NodeName=c[1-2] RealMemory=${AVAIL_MEM} CPUs=${CPU_COUNT} Gres=gpu:${GPU_COUNT} State=UNKNOWN" >> configs/slurm.conf
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
    docker build --build-arg SLURM_VER=${SLURM_VER} --build-arg CUDA_VER=${CUDA_VER} \
        --build-arg ROCM_VER=${ROCM_VER} --build-arg GPU=${GPU} --build-arg MINICONDA_VER=${MINICONDA_VER} \
        -f Dockerfile.${GPU} -t ${IMAGE}:${IMAGE_TAG} .
;;

conda-mgpu)
    rm -rf ${CONDA_PATH}
    conda create -y -p ${CONDA_PATH} python=${PYTHON_VER}
;;

clean)
    set +e
    rm -f configs/*
    docker compose -f docker-compose-${GPU}.yml stop
    docker compose -f docker-compose-${GPU}.yml down
    docker compose -f docker-compose-${GPU}.yml rm -f
    docker volume rm slurm-docker-cluster-gpu_etc_munge slurm-docker-cluster-gpu_etc_slurm  \
        slurm-docker-cluster-gpu_var_lib_mysql slurm-docker-cluster-gpu_var_log_slurm slurm-docker-cluster-gpu_slurm_jobdir
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