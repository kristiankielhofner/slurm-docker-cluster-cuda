ARG CUDA_VER=12.4.1
ARG ROCKY_VER=9

FROM nvidia/cuda:${CUDA_VER}-cudnn-devel-rockylinux${ROCKY_VER}

LABEL org.opencontainers.image.source="https://github.com/kristiankielhofner/slurm-docker-cluster-cuda" \
      org.opencontainers.image.title="slurm-docker-cluster-cuda" \
      org.opencontainers.image.description="Slurm Docker cluster with CUDA on Rocky Linux 9" \
      org.label-schema.docker.cmd="docker compose up -d" \
      maintainer="Kristian Kielhofner"

ARG SLURM_TAG=slurm-21-08-6-1
ARG GOSU_VERSION=1.17
ARG MINICONDA_VER=23.11.0-0 # Version on Frontier as of 5/14/2024

RUN --mount=type=cache,target=/var/cache/dnf dnf makecache \
    && dnf -y update \
    && dnf -y install dnf-plugins-core \
    && dnf install -y 'dnf-command(config-manager)' \
    && dnf config-manager --set-enabled devel \
    && dnf -y install \
       wget \
       bzip2 \
       perl \
       gcc \
       gcc-c++\
       git \
       gnupg \
       make \
       munge \
       munge-devel \
       python3-devel \
       python3-pip \
       python3 \
       mariadb-server \
       mariadb-devel \
       psmisc \
       bash-completion \
       vim-enhanced \
       http-parser-devel \
       json-c-devel \
       && dnf clean all

RUN pip3 install Cython nose

RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

RUN git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin --libdir=/usr/lib64 --with-nvml=/usr/local/cuda \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd \
    && rm -rf slurm \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

RUN wget -O Miniforge3.sh \
    https://github.com/conda-forge/miniforge/releases/download/${MINICONDA_VER}/Miniforge3-${MINICONDA_VER}-Linux-x86_64.sh && \
    bash Miniforge3.sh -b -p "/app/conda" && rm Miniforge3.sh

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
COPY gres.conf /etc/slurm/gres.conf
#COPY cgroup.conf /etc/slurm/cgroup.conf

RUN chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Put us somewhere other than /
WORKDIR /local

CMD ["slurmdbd"]
