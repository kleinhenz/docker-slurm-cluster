#!/bin/bash
set -e

if [ "$1" = "slurmctld" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    sudo -u munge /sbin/munged
    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    exec sudo -u root /opt/slurm/sbin/slurmctld -Dvvv
fi

if [ "$1" = "slurmd" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    sudo -u munge /sbin/munged

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    exec sudo -u root /opt/slurm/sbin/slurmd -Dvvv
fi

exec "$@"
