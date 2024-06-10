# Slurm Docker Cluster with GPU Support

This is a multi-container Slurm cluster using `docker compose`.  The compose file
creates named volumes for persistent storage of MariaDB data files as well as
Slurm state and log directories.

It has been extended to support CUDA/ROCm on Nvidia/AMD devices. By default all available local GPUs are exposed to the control and compute containers.

It will automatically detect CUDA/ROCm/CPU-only and configure itself accordingly.

It attempts to follow the environment you will find on [OLCF Frontier](https://docs.olcf.ornl.gov/systems/frontier_user_guide.html). The main goal of this project is to ease the transition of workloads to Frontier for users more familiar with CUDA/ROCm and less familiar with Slurm and Frontier overall.

While Frontier has AMD GPUs this project enables you to experiment/test/dev with CUDA and then move your project(s) to Frontier/ROCm.

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

## Starting the Cluster

```console
./utils.sh up
```

## Register the Cluster with SlurmDBD

To register the cluster to the slurmdbd daemon, run the `register_cluster.sh`
script:

```console
./utils.sh register
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker compose
> logs -f`

## File Locations

Slurm depends on the control and compute nodes having a consistent environment and filesystem layout. The control and compute nodes have the current working directory of this project mounted at `/local`.

It is high recommended you work from `/local`!

## Accessing the Cluster

Slurm jobs are to be submitted from the control node. The control node has access to all admin functionality and can submit, view, etc jobs.

```console
./utils.sh ctl
```

From the shell, execute slurm commands, for example:

```console
[root@slurmctld /local]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 5-00:00:00      2   idle c[1-2]
```

## Submitting Jobs

The current working directory is mounted on each Slurm container as `/local`.
Therefore, in order to see job output files while on the controller, change to
the `/local` directory when on the **slurmctld** container and then submit a job:

```console
[root@slurmctld /local]# sbatch --wrap="hostname"
Submitted batch job 2
[root@slurmctld /local]# ls
slurm-2.out
[root@slurmctld /local]# cat slurm-2.out
c1
```

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
## Updating the Cluster

If you want to change the `slurm.conf` or `slurmdbd.conf` file without a rebuilding you can do so by calling
```console
./update_slurmfiles.sh slurm.conf slurmdbd.conf
```
(or just one of the files).
The Cluster will automatically be restarted afterwards with
```console
docker compose restart
```
This might come in handy if you add or remove a node to your cluster or want to test a new setting.
