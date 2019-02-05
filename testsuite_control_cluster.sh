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
    *)
        echo "
     Usage: $0 {slurmdownup}

 slurmdownup
	scontrol update NodeName=<node> State=down Reason=hung_proc
	scontrol update NodeName=<node> State=resume
"
        exit 1
esac


