#!/bin/bash

##############################################################################
##
##  Start up script for Vamp Bootstrap on UNIX
##  tested on Centos 6.4
##
##  This script should be called with {name}-{version} of the verticle it should
#   start, without .zip or any other extension.
##  For example, when you want to start vamp-pulse-0.1.0.zip:
##
##  $ ./vamp.sh vamp-pulse-0.1.0
##
##  This script is based on the standard Vert.x startup script
##  https://github.com/eclipse/vert.x
##
##############################################################################

# set font types

bold="\e[1m"
normal="\e[0m"

# Add default JVM options here. You can also use JAVA_OPTS to pass JVM options to this script.
# If you're deploying and undeploying a lot of verticles with dynamic languages it's recommended to enable GC'ing
# of generated classes and prevent OOM due to a lot of gc
# JVM_OPTS="-XX:+CMSClassUnloadingEnabled -XX:-UseGCOverheadLimit"
JVM_OPTS=""

JMX_OPTS=""
# To enable JMX uncomment the following
# JMX_OPTS="-Dcom.sun.management.jmxremote -Dvertx.management.jmx=true -Dhazelcast.jmx=true"

APP_NAME="vamp_bootstrap"
APP_BASE_NAME=`basename "$0"`

# Use the maximum available, or set MAX_FD != -1 to use that value.
MAX_FD="maximum"

warn ( ) {
    echo "$*"
}

die ( ) {
    echo
    echo "$*"
    echo
    exit 1
}

# OS specific support (must be 'true' or 'false').
cygwin=false
msys=false
darwin=false
case "`uname`" in
  CYGWIN* )
    cygwin=true
    ;;
  Darwin* )
    darwin=true
    ;;
  MINGW* )
    msys=true
    ;;
esac

# For Cygwin, ensure paths are in UNIX format before anything is touched.
if $cygwin ; then
    [ -n "$JAVA_HOME" ] && JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
fi

#Attempt to set VAMP_HOME
#Resolve links: $0 may be a link
PRG="$0"
# Need this for relative symlinks.
while [ -h "$PRG" ] ; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=`dirname "$PRG"`"/$link"
    fi
done
SAVED="`pwd`"
cd "`dirname \"$PRG\"`/.."
VAMP_HOME="`pwd -P`"
cd "$SAVED"

#Attempt to set VERTX_HOME
#Resolve links: $0 may be a link
PRG="/usr/bin/vertx"
# Need this for relative symlinks.
while [ -h "$PRG" ] ; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=`dirname "$PRG"`"/$link"
    fi
done
SAVED="`pwd`"
cd "`dirname \"$PRG\"`/.."
VERTX_HOME="`pwd -P`"
cd "$SAVED"

CLASSPATH=${VERTX_HOME}/conf:${VERTX_HOME}/lib/*:${VAMP_HOME}/lib/*

# Determine the Java command to use to start the JVM.
if [ -n "$JAVA_HOME" ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
        # IBM's JDK on AIX uses strange locations for the executables
        JAVACMD="$JAVA_HOME/jre/sh/java"
    else
        JAVACMD="$JAVA_HOME/bin/java"
    fi
    if [ ! -x "$JAVACMD" ] ; then
        die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
    fi
else
    JAVACMD="java"
    which java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
fi

# Increase the maximum file descriptors if we can.
if [ "$cygwin" = "false" -a "$darwin" = "false" ] ; then
    MAX_FD_LIMIT=`ulimit -H -n`
    if [ $? -eq 0 ] ; then
        if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ] ; then
            MAX_FD="$MAX_FD_LIMIT"
        fi
        ulimit -n $MAX_FD
        if [ $? -ne 0 ] ; then
            warn "Could not set maximum file descriptor limit: $MAX_FD"
        fi
    else
        warn "Could not query maximum file descriptor limit: $MAX_FD_LIMIT"
    fi
fi

# For Darwin, add options to specify how the application appears in the dock
if $darwin; then
    GRADLE_OPTS="$GRADLE_OPTS \"-Xdock:name=$APP_NAME\" \"-Xdock:icon=$VERTX_HOME/media/vertx.icns\""
fi

# For Cygwin, switch paths to Windows format before running java
if $cygwin ; then
    VERTX_HOME=`cygpath --path --mixed "$VERTX_HOME"`
    CLASSPATH=`cygpath --path --mixed "$CLASSPATH"`

    # We build the pattern for arguments to be converted via cygpath
    ROOTDIRSRAW=`find -L / -maxdepth 1 -mindepth 1 -type d 2>/dev/null`
    SEP=""
    for dir in $ROOTDIRSRAW ; do
        ROOTDIRS="$ROOTDIRS$SEP$dir"
        SEP="|"
    done
    OURCYGPATTERN="(^($ROOTDIRS))"
    # Add a user-defined pattern to the cygpath arguments
    if [ "$GRADLE_CYGPATTERN" != "" ] ; then
        OURCYGPATTERN="$OURCYGPATTERN|($GRADLE_CYGPATTERN)"
    fi
    # Now convert the arguments - kludge to limit ourselves to /bin/sh
    i=0
    for arg in "$@" ; do
        CHECK=`echo "$arg"|egrep -c "$OURCYGPATTERN" -`
        CHECK2=`echo "$arg"|egrep -c "^-"`                                 ### Determine if an option

        if [ $CHECK -ne 0 ] && [ $CHECK2 -eq 0 ] ; then                    ### Added a condition
            eval `echo args$i`=`cygpath --path --ignore --mixed "$arg"`
        else
            eval `echo args$i`="\"$arg\""
        fi
        i=$((i+1))
    done
    case $i in
        (0) set -- ;;
        (1) set -- "$args0" ;;
        (2) set -- "$args0" "$args1" ;;
        (3) set -- "$args0" "$args1" "$args2" ;;
        (4) set -- "$args0" "$args1" "$args2" "$args3" ;;
        (5) set -- "$args0" "$args1" "$args2" "$args3" "$args4" ;;
        (6) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" ;;
        (7) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" ;;
        (8) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" "$args7" ;;
        (9) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" "$args7" "$args8" ;;
    esac
fi

if [ "x" != "x$VERTX_MODS" ]; then
  VERTX_OPTS="$VERTX_OPTS -Dvertx.mods=$VERTX_MODS"
fi

# Split up the JVM_OPTS And VERTX_OPTS values into an array, following the shell quoting and substitution rules
function splitJvmOpts() {
    JVM_OPTS=("$@")
}
eval splitJvmOpts $JVM_OPTS $JAVA_OPTS $JMX_OPTS $VERTX_OPTS

CLUSTER_PORT=5701
EVENT_BUS_PORT=5702
VERTX_MODULE=$1


exec "$JAVACMD" \
    "${JVM_OPTS[@]}" \
    -Djava.util.logging.config.file=${VAMP_HOME}/conf/logging.properties \
    -Dvertx.home=$VERTX_HOME\
    -classpath "$CLASSPATH" \
    io.magnetic.vamp.Bootstrap run -public_address $PUBLIC_ADDRESS \
                                   -remote_address ${REMOTE_HOST_ADDRESS} \
                                   -local_address ${LOCAL_ADDRESS} \
                                   -cluster_port ${CLUSTER_PORT} \
                                   -event_bus_port ${EVENT_BUS_PORT} \
                                   -vertx_module ${VERTX_MODULE} \
                                   -physical_hostname ${PHYSICAL_HOSTNAME} \
                                    > /dev/null 2>&1 &