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


fix_hostname() {
    echo "############ START fix_hostname"
    exec_pssh "hostname > /etc/hostname"
}


# Check cluster Active

# Init the cluster on node ${NODENAME}1
init_cluster() {
    echo "############ START init the cluster"
}

copy_ssh_key_on_nodes() {
    echo "############ START copy_ssh_key_on_nodes"
    echo "- Generate ssh ssh root key on node ${NODENAME}1"
    exec_on_node ${NODENAME}1 "ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa"
    echo "- Copy ssh root key from node ${NODENAME}1 to all nodes"
    scp -o StrictHostKeyChecking=no root@${NODENAME}1:~/.ssh/id_rsa.pub /tmp/
    scp -o StrictHostKeyChecking=no root@${NODENAME}1:~/.ssh/id_rsa /tmp/
    for i in `seq 2 $NBNODE`
    do
	scp_on_node "/tmp/id_rsa*" "${NODENAME}${i}:/root/.ssh/"
    done
    rm -vf /tmp/id_rsa*
    for i in `seq 2 $NBNODE`
    do
	exec_on_node ${NODENAME}${i} "grep 'Cluster Internal' /root/.ssh/authorized_keys || cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys"
    done
}

ganglia_web() {
    echo "############ START ganglia_web"
    echo "- Enable php7 and restart apache2"
    exec_on_node  ${NODENAME}1 "a2enmod php7"
    exec_on_node  ${NODENAME}1 "systemctl enable apache2"
    exec_on_node  ${NODENAME}1 "systemctl restart apache2"
    exec_on_node  ${NODENAME}1 "systemctl restart gmetad"
    for i in `seq 1 $NBNODE`
    do
	echo "- Enable gmond and restart it"
	exec_on_node ${NODENAME}${i} "systemctl enable gmond"
	exec_on_node ${NODENAME}${i} "systemctl restart gmond"
    done
    echo "- You can access Ganglia Web page at:"
    echo "http://${NODENAME}1/ganglia-web/"

}


slurm_configuration() {

    echo "############ START create a slurm_configuration"

    echo "- Get /etc/slurm/slurm.conf from ${NODENAME}1"
    scp root@${NODENAME}1:/etc/slurm/slurm.conf .

    for i in `seq 1 $NBNODE`
    do
	NODE_LIST="$NODE_LIST,${NODENAME}${i}"
    done
    echo $NODE_LIST

    echo "- Prepare slurm.con file"
    perl -pi -e "s/ClusterName.*/ClusterName=linuxsuse/g" slurm.conf
    perl -pi -e "s/ControlMachine.*/ControlMachine=${NODENAME}1/" slurm.conf
    #NodeName=SLE15sle15hpc1,SLE15sle15hpc2 State=UNKNOWN CoresPerSocket=2 Sockets=2
    perl -pi -e "s/NodeName.*/NodeName=${NODE_LIST} State=UNKNOWN CoresPerSocket=2 Sockets=2/" slurm.conf
    #PartitionName=normal Nodes=SLE15sle15hpc1,SLE15sle15hpc2 Default=YES MaxTime=24:00:00 State=UP
    perl -pi -e "s/PartitionName.*/PartitionName=normal Nodes=${NODE_LIST} Default=YES MaxTime=24:00:00 State=UP/" slurm.conf

    echo "- Copy slurm.conf on all nodes" 
    for i in `seq 1 $NBNODE`
    do
	scp_on_node slurm.conf "${NODENAME}${i}:/etc/slurm/"
    done

    echo "- Enable and start slurmctld/munge on all nodes"
    for i in `seq 1 $NBNODE`
    do
	exec_on_node ${NODENAME}${i} "systemctl enable slurmctld"
	exec_on_node ${NODENAME}${i} "systemctl enable munge"
	exec_on_node ${NODENAME}${i} "systemctl start munge"
	exec_on_node ${NODENAME}${i} "systemctl start slurmctld"
    done

    echo "- Check with sinfo on node ${NODENAME}1"
    exec_on_node ${NODENAME}1 "sinfo"

}


scp_nodes_list() {
    echo "############ START scp_nodes_list"
    echo "- Create nodes file"
    NODESF=/tmp/nodes
    touch ${NODESF}
    for i in `seq 1 $NBNODE`
    do
        echo ${NODENAME}${i} >> ${NODESF}
    done
    echo "- scp nodes file on all nodes"
    for i in `seq 1 $NBNODE`
    do
        scp_on_node ${NODESF} "${NODENAME}${i}:/etc/nodes"
    done
    rm -v ${NODESF}
}
 

##########################
##########################
### MAIN
##########################
##########################


case "$1" in
    hostname)
	fix_hostname
	;;
    sshkeynode)
	copy_ssh_key_on_nodes
	;;
    slurm)
	slurm_configuration
	;;
    ganglia)
	ganglia_web
	;;
    nodeslist)
    scp_nodes_list
    ;;
    all)
	fix_hostname
    scp_nodes_list
    slurm
    ganglia
	;;
    *)
        echo "
     Usage: $0 {hostname|nodeslist|ganglia|sshkeynode|slurm|all} [force]

 status
    Check that the cluster is not running before config

 hostname
    fix /etc/hostname on all nodes

 slurm
    configure slurm on all nodes (and enable and start the service)

 ganglia
    configure apache and get ganglia up

 nodeslist
    copy the full nodes list to all nodes in /etc/nodes file

 sshkeynode
    Copy Cluster Internal key (from ${NODENAME}1) to all other HA nodes

 all 
    run all in this order

 [force]
    use force option to bypass cluster check (dangerous)
"
        exit 1
esac


