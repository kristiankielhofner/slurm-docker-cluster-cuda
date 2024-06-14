#!/usr/bin/env bash
set -ea

# Figure out where we really are
OUR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$OUR_DIR"

if [ -s .env ]; then
    echo "Using .env for configuration"
    . .env
else
    # docker compose needs .env - create empty
    touch .env
fi

# User config locations
DATA_DIR=${DATA_DIR:-./data} # Path to mount in container at /data
CACHE_DIR=${CACHE_DIR:-./.cache} # Path to mount in container at /root/.cache

# Slurm config options
AVAIL_MEM=${AVAIL_MEM:-8192} # Slurm compute node available RAM
CPU_COUNT=${CPU_COUNT:-$(nproc)} # Use number of host CPUs by default

# Used during docker build
CUDA_VER=${CUDA_VER:-12.1.0}
ROCKY_VER=${ROCKY_VER:-9}
ROCM_VER=${ROCM_VER:-5.7.1}

MINICONDA_VER=${MINICONDA_VER:-23.11.0-0} # Version on Frontier as of 6/10/2024
SLURM_VER=${SLURM_VER:-23.02.7} # Version on Frontier as of 6/10/2024

# Docker image configuration
IMAGE=${IMAGE:-slurm-docker-cluster-gpu}
IMAGE_TAG=${IMAGE_TAG:-${SLURM_VER}}

# Local storage root
STORAGE=${STORAGE:-.storage}

# Root home directory
ROOT_HOME=${ROOT_HOME:-${STORAGE}/root}

# System specific storage paths
CCS=${CCS:-${STORAGE}/ccs}
LUSTRE=${LUSTRE:-${STORAGE}/lustre}

# Nvidia has inconsistent docker tagging with cudnn
# Attempt to figure out correct docker base image based on CUDA ver
handle_cuda_tags() {
    case $CUDA_VER in

        12.1*|12.2*)
            CUDA_BASE_TAG="$CUDA_VER-cudnn8-devel"
        ;;

        12.3*)
            CUDA_BASE_TAG="$CUDA_VER-cudnn9-devel"
        ;;

        # Can only test 12.4 or later from here
        *)
            CUDA_BASE_TAG="$CUDA_VER-cudnn-devel"
        ;;

    esac
}

detect_hw() {
    # Default to no GPU (cpu)
    GPU="cpu"

    # Is this device unique to AMD?
    if [ -c /dev/kfd ]; then
        GPU="rocm"
    fi

    # Simple way to check if host has at least one Nvidia device
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

    if [ "$GPU" = "rocm" ]; then
        GPU_COUNT=$(rocm-smi -a --csv | grep card | wc -l)
        echo "Detected $GPU_COUNT AMD GPU(s)"
    fi

    if [ "$GPU" = "cuda" ]; then
        GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv | grep -v name | wc -l)
        echo "Detected $GPU_COUNT Nvidia GPU(s)"
    fi
}

gen_config() {
    mkdir -p .config
    cp config/* .config/

    if [ $GPU_COUNT = 0 ]; then
        echo "NodeName=c[1-2] RealMemory=${AVAIL_MEM} CPUs=${CPU_COUNT} State=UNKNOWN" >> .config/slurm.conf
    else
        if [ "$GPU" = "rocm" ]; then
            AUTO_DETECT="rsmi"
        fi
        if [ "$GPU" = "cuda" ]; then
            AUTO_DETECT="nvml"
        fi
        echo "AutoDetect=$AUTO_DETECT" > .config/gres.conf
        echo "GresTypes=gpu" >> .config/slurm.conf
        echo "NodeName=c[1-2] RealMemory=${AVAIL_MEM} CPUs=${CPU_COUNT} Gres=gpu:${GPU_COUNT} State=UNKNOWN" \
            >> .config/slurm.conf
    fi
}

detect_hw
get_hw_info_cmd
get_num_gpus

case $1 in

# Pass all build args so we can use same command for cuda/rocm/cpu
build)
    handle_cuda_tags
    gen_config
    docker build --build-arg SLURM_VER=${SLURM_VER} --build-arg CUDA_BASE_TAG=${CUDA_BASE_TAG} \
        --build-arg ROCM_VER=${ROCM_VER} --build-arg GPU=${GPU} --build-arg MINICONDA_VER=${MINICONDA_VER} \
        --build-arg ROCKY_VER=${ROCKY_VER} --build-arg CUDA_VER=${CUDA_VER} \
        -f Dockerfile.${GPU} -t ${IMAGE}:${IMAGE_TAG} .
    if [ ! -d ${STORAGE} ]; then
        mkdir -p ${STORAGE}
        cp -a misc/root_home ${ROOT_HOME}
    fi
    detect_hw
    if [ ${GPU} != "rocm" ]; then
        cd ${ROOT_HOME}/bin
        ln -s wrapper rocminfo
        ln -s wrapper rocm-smi
    fi
;;

clean)
    # Allow these commands to fail
    set +e
    rm -rf .config
    docker compose -f docker-compose-${GPU}.yml stop
    docker compose -f docker-compose-${GPU}.yml down
    docker compose -f docker-compose-${GPU}.yml rm -f
    docker volume rm slurm-docker-cluster-gpu_etc_munge slurm-docker-cluster-gpu_etc_slurm  \
        slurm-docker-cluster-gpu_var_lib_mysql slurm-docker-cluster-gpu_var_log_slurm \
        slurm-docker-cluster-gpu_slurm_jobdir 2> /dev/null
;;

config)
    gen_config
;;

# Shell on control node
ctl)
    docker compose -f docker-compose-${GPU}.yml exec -it slurmctld bash
;;

# Just run something on the "cluster"
# In this configuration jobs need to be submitted via the control node/container
run)
    shift
    echo "Running '$@' on control node..."
    docker compose -f docker-compose-${GPU}.yml exec -it slurmctld "$@"
;;

# Shell on compute nodes
c*)
    docker compose -f docker-compose-${GPU}.yml exec -it $1 bash
;;

# You should never need this, just in case...
register)
    docker compose -f docker-compose-${GPU}.yml exec \
        slurmctld bash -c "/usr/bin/sacctmgr --immediate add cluster name=linux" && \
        docker compose -f docker-compose-${GPU}.yml restart slurmdbd slurmctld
;;

# Shell in a fresh base image
# TODO: Expand for GPU support?
shell)
    docker run --rm -it -v ${DATA_DIR}:/data --entrypoint /bin/bash ${IMAGE}:${IMAGE_TAG}
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
    docker compose -f docker-compose-${GPU}.yml "$@"
;;

esac