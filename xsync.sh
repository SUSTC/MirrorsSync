#!/bin/bash

MIRROR=/data/mirrors
PUBLISH=/data/publish
UPSTREAM=mirrors.tuna.tsinghua.edu.cn
LOG=/etc/xmirror/xsync.log

RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[1;34m'
YELLLOW='\033[1;33m'
function try {
    echo -e "Executing ${YELLOW}$@${NC}"
    ERROR=$("$@" 2>&1 >/dev/null) || echo -e "${RED}Error occured when exec $@:\n\t${BLUE}${ERROR}${NC}"
}

function mysleep {
    echo "Waiting for $1 cleanup...";sleep $2
}

function mykill {
    killall $1 >/dev/nul 2>&1 && mysleep $1 $2
}

function sync {
    ls $MIRROR$1 | parallel -j20 --ungroup rsync -avK --timeout=10 rsync://$UPSTREAM$1/{} $MIRROR$1 >>$LOG 2>&1 &
}

function sync_job {
    #ubuntu
    for part in $UBUNTU_POOL ; do
        sync /ubuntu/pool/$part
    done
    sync /ubuntu/dists
    #ros
    sync /ros/ubuntu/dists
    sync /ros/ubuntu/pool/main
    #archlinux
    sync /archlinux
    sync /archlinuxarm
    sync /archlinuxcn
    #raspi
    sync /raspbian
    #cygwin
    sync /cygwin
    #qt
    sync /qt
}

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}" 1>&2
   exit 1
fi

mykill perl 10
mykill rsync 10
try btrfs subvolume delete $PUBLISH
try btrfs subvolume snapshot -r $MIRROR $PUBLISH

sync_job