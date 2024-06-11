# Slurm Docker Cluster with GPU Support

This is a multi-container Slurm cluster using `docker compose`.  The compose file creates named volumes for persistent storage of MariaDB data files as well as Slurm state and log directories.

It has been extended to support CUDA/ROCm on Nvidia/AMD devices. By default all available local GPUs are exposed to the control and compute containers.

It will automatically detect CUDA/ROCm/CPU-only, number of GPUs (if any), and configure itself accordingly.

It attempts to approximate the environment you will find on [OLCF Frontier](https://docs.olcf.ornl.gov/systems/frontier_user_guide.html). The main goal of this project is to ease the transition of workloads to Frontier for users familiar with CUDA/ROCm and less familiar with Slurm and Frontier overall. This can be very useful for developing/debugging Slurm workloads utilizing multiple compute nodes on a single system with as few as one GPU and the simplicity of `docker compose`.

While Frontier has AMD GPUs this project enables you to experiment/test/dev with Nvidia/CUDA and then move your project(s) to Frontier/ROCm. Of course if you have AMD GPUs on your host system you will emulate Frontier more accurately.

By default the current recommended Frontier miniforge environment is pre-installed for ease of use with python-based user projects.

## Containers and Volumes

The compose file will run the following containers:

* mysql
* slurmdbd
* slurmctld
* c1 (slurmd)
* c2 (slurmd)

The compose file will create the following named volumes:

* etc_munge         ( -> `/etc/munge`     )
* etc_slurm         ( -> `/etc/slurm`     )
* slurm_jobdir      ( -> `/data`          )
* var_lib_mysql     ( -> `/var/lib/mysql` )
* var_log_slurm     ( -> `/var/log/slurm` )

It will also expose the current working directory at `/local`.

## Building the Docker Image

Build the image locally:

```console
./utils.sh build
```

By default the containers will be build with CUDA 12.1.0 on Nvidia systems and ROCm 5.7.1 on AMD systems. You can change these by setting the appropriate environment variable on build. For example:

```console
CUDA_VER=12.4.1 ./utils.sh build
```
-or-

```console
ROCM_VER=6.1.2 ./utils.sh build
```

This only needs to be set at build time. To make it consistent for future builds, etc you can add it to `.env`.

> NOTE: ROCm has fairly limited official GPU support. If you would like to try to use an unsupported GPU you can force "support" by adding the appropriate environment variable to `.env`:

```console
cat .env
HSA_OVERRIDE_GFX_VERSION=11.0.0
```

This will set this (and any other environment variables present) in the appropriate docker containers. Tested with RX 7800 XT but of course your mileage may very.

## Starting the Cluster

```console
./utils.sh up
```

## File Locations

Slurm depends on the control and compute nodes having a consistent environment and filesystem layout. The control and compute nodes have the current working directory of this project mounted at `/local`.

It is high recommended you work from `/local`!

## Accessing the Cluster

Slurm jobs are to be submitted from the control node. The control node has access to all admin functionality and can submit, view, etc jobs.

```console
./utils.sh ctl
```

Once inside the control container you can execute slurm commands, for example:

```console
[root@slurmctld /local]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
batch*       up    2:00:00      2   idle c[1-2]
batch-dev    up   infinite      2   idle c[1-2]
```

> NOTE: There are two partitions available. The default partition `batch` has the Frontier default time limit of 2 hours. There is also a `batch-dev` partition for debugging workloads you can't get to run within two hours on your system (due to available compute resources, GPU sharing, etc). If you use `batch-dev` here you will need to remember to update your scripts to use `batch` on Frontier!

## Submitting Jobs

The current working directory is mounted on each Slurm container as `/local`. Therefore, in order to see job output files while on the controller, change to the `/local` directory when on the **slurmctld** container and then submit a job:

```console
[root@slurmctld /local]# sbatch --wrap="hostname"
Submitted batch job 2
[root@slurmctld /local]# ls
slurm-2.out
[root@slurmctld /local]# cat slurm-2.out
c1
```

## GPU Examples

### CUDA with two GPUs (RTX 4090) on host

```console
slurm-docker-cluster-gpu$ ./utils.sh ctl
Detected 2 Nvidia GPU(s)
[root@slurmctld local]# srun -N2 --gres=gpu:2 nvidia-smi
Tue Jun 11 04:53:34 2024       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.90.07              Driver Version: 550.90.07      CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 4090        Off |   00000000:41:00.0 Off |                  Off |
| 32%   50C    P2            231W /  480W |    5812MiB /  24564MiB |     60%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   1  NVIDIA GeForce RTX 4090        Off |   00000000:61:00.0  On |                  Off |
|  0%   33C    P8             41W /  480W |    3804MiB /  24564MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
+-----------------------------------------------------------------------------------------+
Tue Jun 11 04:53:34 2024       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.90.07              Driver Version: 550.90.07      CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 4090        Off |   00000000:41:00.0 Off |                  Off |
| 32%   50C    P2            231W /  480W |    5812MiB /  24564MiB |     60%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
|   1  NVIDIA GeForce RTX 4090        Off |   00000000:61:00.0  On |                  Off |
|  0%   33C    P8             41W /  480W |    3804MiB /  24564MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
+-----------------------------------------------------------------------------------------+
[root@slurmctld local]#
```

### ROCm with one GPU (MI210) on host

```console
slurm-docker-cluster-gpu$ ./utils.sh ctl
Detected 1 AMD GPU(s)
[root@slurmctld local]# srun -N2 --gres=gpu:1 rocm-smi


========================= ROCm System Management Interface =========================
=================================== Concise Info ===================================
GPU  Temp (DieEdge)  AvgPwr  SCLK    MCLK     Fan  Perf  PwrCap  VRAM%  GPU%  
0    44.0c           42.0W   800Mhz  1600Mhz  0%   auto  300.0W    0%   0%    
====================================================================================
=============================== End of ROCm SMI Log ================================


========================= ROCm System Management Interface =========================
=================================== Concise Info ===================================
GPU  Temp (DieEdge)  AvgPwr  SCLK    MCLK     Fan  Perf  PwrCap  VRAM%  GPU%  
0    44.0c           42.0W   800Mhz  1600Mhz  0%   auto  300.0W    0%   0%    
====================================================================================
=============================== End of ROCm SMI Log ================================
[root@slurmctld local]#
```

You can see from these examples that each compute node (c1-c2) share and have access to available host GPUs.

> NOTE: Because the GPUs are shared on compute nodes you will likely have to adjust batch size, etc for available VRAM.

## Stopping and Restarting the Cluster

```console
./utils.sh stop
./utils.sh start
```

## Deleting the Cluster

To remove all containers and volumes, run:

```console
./utils.sh clean
```

## Updating the cluster

If you change host configuration (number/type of GPUs, etc) you need to clean and rebuild:

```console
./utils.sh clean
./utils.sh build
```

## Register the Cluster with SlurmDBD

In rare instances it may be necessary to force registration of the cluster.

To force register the cluster to the slurmdbd daemon, run `./utils.sh register`:

```console
./utils.sh register
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker compose
> logs -f`
