#!/bin/sh
#########################################################
#
#
#########################################################
## INIT nodes / SOME CHECKS
#########################################################
# all is done from the Host


if [ -f `pwd`/functions ] ; then
    . `pwd`/functions
else
    echo "! need functions in current path; Exiting"; exit 1
fi
check_load_config_file


slurm_down_up() {
	echo $I "############ START slurm_down_up" $O
	exec_on_node ${NODENAME}1 "scontrol show node"
	exec_on_node ${NODENAME}1 "sinfo"
	exec_on_node ${NODENAME}1 "scontrol update NodeName=${NODENAME}[1-${NBNODE}] State=down Reason=hung_proc"
	sleep 3
	exec_on_node ${NODENAME}1 "scontrol update NodeName=${NODENAME}[1-${NBNODE}] State=resume"
	exec_on_node ${NODENAME}1 "sinfo"
}

cmd_on_nodes() {
    echo $I "############ START cmd" $O
    if [ -z "$*" ]; then echo "- First arg must be the command!"; exit 1; fi
    CMD="$*"
    for i in `seq 1 $NBNODE`
    do
        exec_on_node ${NODENAME}${i} "$CMD"
    done
}


#scontrol show job
#scontrol show partition

##########################
##########################
### MAIN
##########################
##########################


case "$1" in
    slurmdownup)
	slurm_down_up
	;;
    scc)
        enable_SCC_repo
        ;;
    cleanrepo)
        cleanup_zypper_repo
        ;;
    update)
        update_nodes
        ;;
    start)
        start_vm
        ;;
    stop)
        stop_vm
        ;;
    cmd)
	cmd_on_nodes $2
        ;;
    install)
        install_package $2
        ;;

    *)
        echo "
 media
    enable DVD media on all nodes

 scc
    enable SCC repo and add PackageHub repo
 
 cleanrepo
    disable SCC (cleanup) and remove all zypper repo

 update
    update all nodes with latest packages

 start
    start all nodes

 stop 
    stop all nodes

 install
    install package name (or list)

 slurmdownup
	scontrol update NodeName=<node> State=down Reason=hung_proc
	scontrol update NodeName=<node> State=resume
"
        exit 1
esac


