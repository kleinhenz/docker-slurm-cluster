FROM       centos:8 as base
MAINTAINER Joseph Kleinhenz <jkleinh@umich.edu>

RUN yum -y update \
    && yum -y install \
    readline-devel \
    openssl-devel \
    sudo \
    && yum clean all \
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
    && yum clean all \
    && rm -rf /var/cache/yum

## install munge
RUN mkdir -p /build/munge && cd /build/munge \
    && curl -L https://github.com/dun/munge/archive/munge-0.5.14.tar.gz | tar xvz --strip 1 \
    && ./bootstrap \
    && ./configure \
    && make \
    && make install

# install slurm
RUN mkdir -p /build/slurm && cd /build/slurm \
    && curl -L https://download.schedmd.com/slurm/slurm-20.02.3.tar.bz2 | tar xvj --strip 1 \
    && ./configure \
    && make \
    && make install

FROM base as slurm
COPY --from=builder /usr/local /usr/local

# add /usr/local/lib to dynamic linker search path
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && ldconfig

# setup munge
RUN mungekey -c \
    && groupadd -r --gid=994 munge \
    && useradd -r -g munge --uid=994 munge \
    && chown -R munge:munge /usr/local/etc/munge /usr/local/var/log/munge /usr/local/var/run/munge /usr/local/var/lib/munge

# setup slurm
RUN groupadd -r --gid=995 slurm \
    && useradd -r -g slurm --uid=995 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/log/slurm/acct.log \
    && chmod +r /var/log/slurm/acct.log \
    && chown -R slurm:slurm /var/*/slurm*

## create docker user and allow it to start services
RUN groupadd --gid=991 docker \
    && useradd -m -s /bin/bash -g docker --uid=991 docker \
    && echo "docker ALL=(munge) NOPASSWD:/usr/local/sbin/munged" >> /etc/sudoers.d/docker \
    && echo "docker ALL=(slurm) NOPASSWD:/usr/local/sbin/slurmctld" >> /etc/sudoers.d/docker \
    && echo "docker ALL=(root) NOPASSWD:/usr/local/sbin/slurmd" >> /etc/sudoers.d/docker

USER    docker
WORKDIR /home/docker

# update bashrc for interactive use
RUN echo "alias ll='ls -l --color=auto'" >> .bashrc

COPY slurm.conf /usr/local/etc/slurm.conf

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD /bin/bash -l
