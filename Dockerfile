FROM       rockylinux:9 as base
MAINTAINER Joseph Kleinhenz <jkleinh@umich.edu>

RUN dnf -y update \
    && dnf -y install dnf-plugins-core \
    && dnf config-manager --set-enabled crb \
    && dnf -y install \
    readline-devel \
    openssl-devel \
    dbus-devel \
    bpftrace \
    sudo \
    munge \
    munge-devel \
    && dnf clean all \
    && rm -rf /var/cache/yum

FROM base as builder

RUN yum -y update \
    && yum -y install \
    gcc \
    python3 \
    perl \
    bzip2 \
    autoconf \
    automake \
    libtool \
    vim \
    && yum clean all \
    && rm -rf /var/cache/yum

# install slurm
RUN mkdir -p /build/slurm && cd /build/slurm \
    && curl -L https://github.com/SchedMD/slurm/archive/refs/tags/slurm-24-05-5-1.tar.gz | tar xz --strip 1 \
    && ./configure --prefix=/opt/slurm \
    && make \
    && make install

FROM builder as slurm
COPY --from=builder /opt/slurm /opt/slurm
ENV PATH=/opt/slurm/bin:${PATH}

# setup slurm
RUN groupadd -r --gid=995 slurm \
    && useradd -r -g slurm --uid=995 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/spool/slurmctld \
        /var/run/slurmd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/log/slurm/acct.log \
    && chmod +r /var/log/slurm/acct.log \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

## create docker user and allow it to start services
RUN groupadd --gid=991 docker \
    && useradd -m -s /bin/bash -g docker --uid=991 docker \
    && echo "docker ALL=(munge) NOPASSWD:/sbin/munged" >> /etc/sudoers.d/docker \
    && echo "docker ALL=(slurm) NOPASSWD:/opt/slurm/sbin/slurmctld" >> /etc/sudoers.d/docker \
    && echo "docker ALL=(root) NOPASSWD:/opt/slurm/sbin/slurmd" >> /etc/sudoers.d/docker \
    && echo "docker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/docker

USER    docker
WORKDIR /home/docker
COPY slurm.conf /opt/slurm/etc/slurm.conf
COPY cgroup.conf /opt/slurm/etc/cgroup.conf

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD /bin/bash -l
