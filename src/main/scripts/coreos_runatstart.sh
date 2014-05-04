#!/bin/bash

##############################################################################
##
##  This script does some necessary setup before we can startup Docker:
##  -   it publishes the public IP of the current host to ETCD. This way,
##      we can use it on another host to connect Hazelcast and Vertx
##
##  -   it sets an environment variable with the docker0 address, so we
##      can pass it into the Docker container and use it to to connect to
##      ETCD.
##
##      tested on CoreOS
##
##############################################################################

# Grab the public IP address and hostname
#PUBLIC_ADDRESS=`ifconfig enp0s8 | grep 'inet ' | awk '{print $2}'`
PUBLIC_ADDRESS=`sudo su -c 'echo $COREOS_PUBLIC_IPV4'`
HOST_NAME=`hostname`

# Set public address as a key in ETCD
curl -L http://127.0.0.1:4001/v2/keys/hosts/${HOST_NAME} \
                -XPUT -d value=${PUBLIC_ADDRESS}
# export it
export PUBLIC_ADDRESS

#Set docker0 address as an environment variable
export DOCKER0_ADDRESS=`ifconfig docker0 | grep 'inet ' | awk '{print $2}'`