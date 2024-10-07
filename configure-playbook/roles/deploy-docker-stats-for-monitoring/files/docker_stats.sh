#!/bin/bash

STATS_DIR="/mnt/shared/docker_stats"
NODE=`hostname -s | grep -o '[1-3]'`
mkdir -p $STATS_DIR/$NODE
DOCKER_STATS=""
SECONDS=0
while (( $SECONDS < 58 ));
do
    DOCKER_STATS+="`docker stats --format '{{.Name}}: {{.CPUPerc}} {{.MemPerc}}' --no-stream`
"
done
STACKS=`echo "$DOCKER_STATS" | grep -P '^(devel|review|catalog)-' | sed -e 's/^\([^-]*-[^-]*\)-.*/\1/' | sort -u`
for STACK in $STACKS;
do
    STATS_FOR_STACK=`echo "$DOCKER_STATS" | grep "^$STACK" | sed -e 's/^[^-]*-[^-]*-\([^.]*\)\.[^:]*:\(.*\)$/\1\2/'`
    CONTAINERS=`echo "$STATS_FOR_STACK" | sed -e 's/^\([^ ]*\) .*$/\1/' | sort -u`
    OUTPUT_FOR_STACK=""
    for CONTAINER in $CONTAINERS;
    do
        AVERAGES=`echo "$STATS_FOR_STACK" | grep "^$CONTAINER" | awk '{ total_cpu += $2; total_mem += $3 } END { print total_cpu/NR, total_mem/NR }'`
        OUTPUT_FOR_STACK+="$CONTAINER $AVERAGES
"
    done
    echo "$OUTPUT_FOR_STACK" >"$STATS_DIR/$NODE/$STACK"
done
