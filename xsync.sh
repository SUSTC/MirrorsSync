#!/bin/bash

MIRROR=/data/mirrors
PUBLISH=/data/publish
UPSTREAM=mirrors.tuna.tsinghua.edu.cn
LOG=/etc/xmirror

RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[1;34m'
YELLLOW='\033[1;33m'
function try {
    echo -e "Executing ${YELLOW}$@${NC}"
    ERROR=$("$@" 2>&1 >/dev/null) || echo -e "${RED}Error occured when exec $@:\n\t${BLUE}${ERROR}${NC}"
}

# checkprocess [processName] [processNum] [do if larger than $2]
function checkprocess {
    PROCESS_NUM=$(ps -ef | grep "$1" | grep -v "grep" | wc -l)
    if [ $PROCESS_NUM -gt $2 ];
    then
        $3
        return -1
    else
        return 0
    fi
}

function sync {
    ls $MIRROR$1 | parallel -j20 --ungroup rsync -avK --timeout=10 rsync://$UPSTREAM$1/{} $MIRROR$1 >>$LOG/xsync.log 2>&1 &
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

#cron job run this scrip every 4h(=48*300s)
max_wait_times=45
exit_code=-1
while [[ ($max_wait_times -gt 0) || ($exit_code -eq -1) ]]; do
    max_wait_times=$[$max_wait_times-1]
    echo "Wait for rsync jobs."
    checkprocess rsync 0 "sleep 300"
    exit_code=$?
done
exit_code=-1
while [[ ($max_wait_times -gt 0) || ($exit_code -eq -1) ]]; do
    max_wait_times=$[$max_wait_times-1]
    echo "Wait for rsync parallel complete."
    checkprocess perl 0 "sleep 300"
    exit_code=$?
done
if [[ $max_wait_times -eq -1 ]]; then
    echo "Last sync job not complete, quit."
    exit 1
fi

# compress last log file
try tar -jcvf "$LOG_PATH/$(date +%m-%d_%H-%M-%S)_log.tar.bz2" $LOG_PATH/xsync.log
try rm -f "$LOG_PATH/xsync.log"

try btrfs subvolume delete $PUBLISH
try btrfs subvolume snapshot -r $MIRROR $PUBLISH

sync_job