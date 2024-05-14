# Slurm Docker Cluster with CUDA

This is a multi-container Slurm cluster using `docker compose`.  The compose file
creates named volumes for persistent storage of MariaDB data files as well as
Slurm state and log directories.

It has been extended to support CUDA on Nvidia devices. By default all available local Nvidia GPUs are exposed to the control and compute containers.

It attempts to follow the environment you will find on [OLCF Frontier](https://docs.olcf.ornl.gov/systems/frontier_user_guide.html). The main goal of this project is to ease the transition of workloads to Frontier for users more familiar with CUDA and less familiar with Slurm, AMD, ROCm, and Frontier overall.

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

Build a different version of Slurm using Docker build args and the Slurm Git
tag:

```console
docker build --build-arg SLURM_TAG="slurm-19-05-2-1" -t slurm-docker-cluster:19.05.2 .
```

Or equivalently using `docker-compose`:

```console
SLURM_TAG=slurm-19-05-2-1 IMAGE_TAG=19.05.2 docker-compose build
```


## Starting the Cluster

Run `docker-compose` to instantiate the cluster:

```console
docker compose up -d
```

## Register the Cluster with SlurmDBD

To register the cluster to the slurmdbd daemon, run the `register_cluster.sh`
script:

```console
./register_cluster.sh
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker compose
> logs -f`

## Accessing the Cluster

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
docker compose stop
docker compose start
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
