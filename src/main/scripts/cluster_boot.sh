#!/bin/bash

##############################################################################
##
##  This script runs inside a Docker instance and does the following
##  -   it sets initial configuration
##  -   it sets initial keys in ETCD
##  -   it announces the service in ETCD
##  -   it passes the vertx module to the Vamp Bootstrap process
##
##  clusterboot.sh relies on the following environment variables:
##
##  $DOCKER0_ADDRESS        - the IP of the Docker bridge
##  $PUBLIC_ADDRESS         - the external IP of the host running Docker
##  $PHYSICAL_HOSTNAME      - the hostname of the host running Docker
##
##
##  For example, when you want to start vamp-pulse-0.1.0.zip:
##
##  $ ./cluster_boot.sh vamp-pulse-0.1.0
##
##
##  This script is based on the great work by deis:
##  https://github.com/deis/
##
##############################################################################

# version

version=1.1

# set font types

bold="\e[1;36m"
normal="\e[0m"

# Print the cocky banner
# Font by http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=vamp%0A

red="\e[0;31m"
yellow="\e[0;33m"
green="\e[0;32m"
blue="\e[0;34m"
purple="\e[0;35 m"
normal="\e[0m"
echo -e ""
echo -e "${red}██╗   ██╗ █████╗ ███╗   ███╗██████╗  "
echo -e "${yellow}██║   ██║██╔══██╗████╗ ████║██╔══██╗ "
echo -e "${green}██║   ██║███████║██╔████╔██║██████╔╝ "
echo -e "${blue}╚██╗ ██╔╝██╔══██║██║╚██╔╝██║██╔═══╝  "
echo -e "${purple} ╚████╔╝ ██║  ██║██║ ╚═╝ ██║██║      "
echo -e "${red}  ╚═══╝  ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝      "
echo -e "${normal}                       version ${version}"
echo -e "${normal}                       by magnetic.io"
echo -e ""


# set directory in which the script is
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e  "${bold}==> Starting cluster bootstrap..."

# set debug based on envvar
[[ $DEBUG ]] && set -x

# The ETCD IP address to which we can connect from inside Docker. This has to passed in at startup of the container.
export ETCD_HOST=$DOCKER0_ADDRESS

# The public IP address of the parent host. This has to be passed in at startup of the container
export PUBLIC_IP=$PUBLIC_ADDRESS

# The hostname of the physical host/vm that is running Docker
export PHYSICAL_HOSTNAME=$PHYSICAL_HOSTNAME

# The randomized hostname of the current Docker container.
export CONTAINER_HOSTNAME=$HOSTNAME

# The public port used to establish Hazelcast connection
export PORT_HC=${PORT_HC:-5701}

# The public port used to establish the Vert.X event bus
export PORT_EB=${PORT_EB:-5702}

# Vertx Module to pass to Vamp Bootstrap
export VERTX_MODULE=$1

# configure etcd
export ETCD_PORT=${ETCD_PORT:-4001}
export ETCD="$ETCD_HOST:$ETCD_PORT"
export ETCD_PATH=${ETCD_PATH:-/vamp/bootstrap}
export ETCD_TTL=${ETCD_TTL:-10}

echo -e  "${bold}==> info: Connecting to ETCD"

MAX_RETRIES_CONNECT=10
retry=0

# wait for etcd to be available
until curl -L http://$ETCD/v2/keys/ > /dev/null 2>&1; do
	echo -e  "${normal}==> info: Waiting for etcd at $ETCD..."
	sleep $(($ETCD_TTL/2))  # sleep for half the TTL
	if [[ "$retry" -gt $MAX_RETRIES_CONNECT ]]; then
	echo -e  "==> error: Exceed maximum of ${MAX_RETRIES_CONNECT}...exiting"
	exit 1
	fi
	((retry++))
done

# wait until etcd has discarded potentially stale values
sleep $(($ETCD_TTL+1))

echo -e  "${normal}==> info: Connected to ETCD at $ETCD"

# Try to determine if there already is a host we can connect to with the Hazelcast/Eventbus
REMOTE_HOST_ADDRESS=`curl -sL http://$ETCD/v2/keys/vamp/bootstrap | \
                        sed -e 's/[{}]/''/g' | \
                        awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | \
                        grep -E vamp/bootstrap/ | \
                        grep -v $PUBLIC_ADDRESS | \
                        cut -d'/' -f4 | \
                        sed 's/"//g' | \
                        head -n 1`

if [[ ! -z $REMOTE_HOST_ADDRESS ]]; then
    echo -e  "${normal}==> info: Vamp Bootstrap will try to cluster with started remote host ${REMOTE_HOST_ADDRESS}"
    else
    echo -e  "${normal}==> info: Found no remote hosts: Vamp Bootstrap will start unclustered"
fi

export REMOTE_HOST_ADDRESS=$REMOTE_HOST_ADDRESS

# Get the local address when running a Docker container in 'bridged' mode
LOCAL_ADDRESS=`ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

# When running in 'host' mode on Vagrant, the network devices is not eth0 but enp0s3
if [[ -z $LOCAL_ADDRESS ]]; then
 echo -e  "${bold}==> info: Couldn't determine local address on eth0, trying enp0s3"
 LOCAL_ADDRESS=`ifconfig enp0s3 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
fi

export LOCAL_ADDRESS=$LOCAL_ADDRESS

echo -e  "${normal}==> info: Hazelcast port \t=> $PORT_HC"
echo -e  "${normal}==> info: Vertx Eventbus port \t=> $PORT_EB"
echo -e  "${normal}==> info: ETCD host \t\t=> $ETCD_HOST"
echo -e  "${normal}==> info: ETCD port \t\t=> $ETCD_PORT"
echo -e  "${normal}==> info: ETCD base path \t=> $ETCD_PATH"
echo -e  "${normal}==> info: Public IP \t\t=> $PUBLIC_IP"
echo -e  "${normal}==> info: Local IP \t\t=> $LOCAL_ADDRESS"
echo -e  "${normal}==> info: Physical hostname \t=> $PHYSICAL_HOSTNAME"
echo -e  "${normal}==> info: Container hostname \t=> $CONTAINER_HOSTNAME"
echo -e  "${normal}==> info: Vertx module to run \t=> $VERTX_MODULE"


echo -e  "${bold}==> info: Starting Vamp Bootstrap with module ${VERTX_MODULE}"

# spawn vamp bootstrapper in the background
$SCRIPT_DIR/vamp.sh $VERTX_MODULE &
VAMP_PID=$!

# smart shutdown on SIGINT and SIGTERM
function on_exit() {
	kill -TERM $VAMP_PID
	wait $VAMP_PID
}
trap on_exit INT TERM

# publish the service to etcd
if [[ ! -z $PORT_HC ]]; then

	# configure service discovery
    PROTO=${PROTO:-tcp} 

	set +e

	# wait for the service to become available on PUBLISH port
        sleep 1 && while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$PUBLISH\" && \$1 ~ \"$PROTO.?\"") ]] ; do
	echo -e  "${normal}==> info: Waiting for Vamp Bootstrap to come online..."
	sleep 3;
	done

	echo -e  "${normal}==> info: Vamp Bootstrap was started with PID ${VAMP_PID} and public IP ${PUBLIC_ADDRESS}"

	# while the port is listening, publish to etcd
	while [[ ! -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$PUBLISH\" && \$1 ~ \"$PROTO.?\"") ]] ; do
	    curl -L http://$ETCD/v2/keys$ETCD_PATH/$PUBLIC_ADDRESS -XPUT -d ttl=$ETCD_TTL >/dev/null 2>&1
		sleep $(($ETCD_TTL/2)) # sleep for half the TTL
	done
	# if the loop quits, something went wrong
	exit 1

fi

wait