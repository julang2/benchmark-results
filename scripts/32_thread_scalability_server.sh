#!/bin/bash

# threads scalability - for data fitting into memory (cache size 210GB)
# run in range of threads 1 3 5 8 13 20 31 46 68 100 145 210 300 430 630 870 1000 1200 
# run sysbench mongodb OLTP and OLTP_RW

DBPATH=/data/sam/mongod/
BACKUPS_PATH=/home/fipar/PERF-22/backups_large/
# actual data dir is under $BACKUPS_PATH/${distribution}_${version}-${engine}/$engine
WORKSPACE=/home/fipar/perf-32/
SIZE=60000000
MONGO=/home/fipar/perf-32/mongo/percona-server-mongodb-3.2.4-1.0rc2/bin/mongo
THREADS="1 3 5 8 13 20 31 46 68 100 145 210 300 430 630 870 1000 1200"

set_cgroup()
{
    [ $# -eq 0 ] && echo "usage: set_cgroup <pid> <memory limit>">&2 && return 1
    # create cgroup if needed, then cgclassify
}

wait_for_mongod()
{
    echo -n "Waiting for mongod ($engine) to become ready ..."
    while [ $(echo 'db.isMaster()' | $MONGO 2>/dev/null|grep ismaster|grep -c true) -eq 0 ]; do
	sleep 0.3
    done
    echo "Done"
}

start_mongod()
{
    [ $# -eq 0 ] && echo "usage: start_mongod <engine> <cache size> <cgroup memory limit, 0 for no limit> [extra mongod args]">&2 && return 1
    engine=$1
    cache=$2
    memory=$3
    shift 3
    sudo rm -f $DBPATH/journal/* # we remove the journal files so we can run benchmarks with and without journal compression
    sudo nohup ./start-$engine.sh $cache $* &> $engine.log &
    if [ $memory -gt 0 ]; then
	set_cgroup $! $memory
    fi
    wait_for_mongod
}

stop_mongod()
{
    [ -n "$(pidof mongod)" ] && {
	echo -n "Stopping mongod ..."
	sudo kill $(pidof mongod)
	i=0
	while [ -n "$(pidof mongod)" ]; do
	    i=$((i+1))
	    [ $i -ge 20 ] && break
	    sleep 0.3
	done
	echo "Done"
	[ $i -ge 20 ] && sudo kill -9 $(pidof mongod) && echo "Sleeping 120 seconds after SIGKILLing mongod" && sleep 120
    }
}

restore_datadir()
{
    [ $# -eq 0 ] && echo "usage: restore_datadir <distribution> <engine>">&2 && return 1
    distribution=$1; engine=$2
    sudo rm -rf $DBPATH/*
    sudo cp -rv $BACKUPS_PATH/${distribution}_3.2-${engine}/$engine/* $DBPATH/
}

cd $WORKSPACE
eval $*
