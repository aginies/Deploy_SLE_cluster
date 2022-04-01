#!/bin/sh
#########################################################
#
#
#########################################################
## DUPLICATION TEST
#########################################################
#

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
if [ -f "${PWD}/nodes_ressources" ] ; then
    . ${PWD}/nodes_ressources
else
    echo "! functions file nodes_ressources needed! ; Exiting"
    exit 1
fi
check_load_config_file other


DATA="vdd"
diskname="disk"
CLUSTERDUP="DUP"
TESTDIR="/mnt/test"
# size of the image to duplicate (in MB)
SIZEM="5120"

# BIG CLUSTER CONFIG !
NBNODE=4
IMAGENB=${NBNODE}

dolly_add_repo() {
    echo $I "############ START dolly_repo" $O
    for i in `seq 1 $NBNODE`
    do
        echo "- Node ${NODENAME}${i}:"
	#ONLY AVAILABLE ON SLE_15_SP3 currently
        #exec_on_node_screen ${NODENAME}${i} "zypper addrepo https://download.opensuse.org/repositories/network:/cluster/SLE_${SLERELEASE}_${SPVERSION} dolly"
        exec_on_node ${NODENAME}${i} "zypper addrepo https://download.opensuse.org/repositories/network:/cluster/SLE_${SLERELEASE}_SP3 dolly"
        exec_on_node ${NODENAME}${i} "zypper --gpg-auto-import-keys ref dolly"
    done
}

dolly_remove_repo() {
    echo $I "############ START dolly_remove_repo" $O
    for i in `seq 1 $NBNODE`
    do
        echo "- Node ${NODENAME}${i}:"
        exec_on_node ${NODENAME}${i} "zypper removerepo dolly"
    done
}


install_dolly() {
    echo $I "############ START install_dolly" $O
    echo $I "-Install all tools on all nodes" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Node ${NODENAME}${i}:"
	exec_on_node ${NODENAME}${i} "zypper in -y --allow-vendor-change dolly"
    done
}

run_server_dup() {
  echo $I "############ START run_server_dup" $O
  echo $I "- Start server on node ${NODENAME}1" $O
  for i in `seq 2 $NBNODE`
  do
      VALUE=`echo -n ${NODENAME}${i}`
      if [ ! -z "${LISTNODE}" ]; then
	  LISTNODE=${LISTNODE},${VALUE}
      else
	  LISTNODE=${VALUE}
      fi
  done
  echo
  echo "Log on ${NODENAME}1 and run dolly:"
  echo "ssh ${NODENAME}1"
  echo "dolly -dvs -H ${LISTNODE} -I /dev/${DATA} -O /dev/${DATA}"
}

run_duplication() {
   echo $I "############ START run_duplication" $O
   echo $I "- Start client on all other nodes" $O
   for i in `seq 2 $NBNODE`
   do
	echo "- Killall -9 dolly on nodes ${NODENAME}${i} in case of..."
	ssh ${NODENAME}${i} "killall -9 dolly"
	echo "ssh ${NODENAME}${i} \"screen -d -m dolly -v\""
	ssh ${NODENAME}${i} "screen -d -m dolly -v"
	sleep 1
   done
}

config_set() {
   echo $I "############ START config_set" $O
   CLIENTS=`echo $((${NBNODE}-1))`
   cat > dolly.cfg <<EOF
infile /dev/${DATA}
outfile /dev/${DATA}
server ${NODENAME}1
firstclient ${NODENAME}2
lastclient ${NODENAME}${NBNODE}
clients ${CLIENTS}
EOF
for i in `seq 2 $NBNODE`
do
echo "${NODENAME}${i}" >> dolly.cfg
done
echo "endconfig" >> dolly.cfg
scp_on_node dolly.cfg "root@${NODENAME}1:/etc/"
echo "- CONFIGURATION:"
echo "################"
cat dolly.cfg
echo "################"
rm dolly.cfg
}

create_pool_storage() {
    echo $I "############ START create_pool_storage" $O
    virsh pool-list --all | grep ${CLUSTERDUP} > /dev/null
    if [ $? == "0" ]; then
        echo $W "- Destroy current pool ${CLUSTERDUP}" $O
        virsh pool-destroy ${CLUSTERDUP}
        echo $W "- Undefine current pool ${CLUSTERDUP}" $O
        virsh pool-undefine ${CLUSTERDUP}
        #rm -vf ${SBDDISK}
    else
        echo $W "- ${CLUSTERDUP} pool is not present" $O
    fi
    echo $I "- Define pool ${CLUSTERDUP}" $O
    mkdir -p ${STORAGEP}/${CLUSTERDUP}
    virsh pool-define-as --name ${CLUSTERDUP} --type dir --target ${STORAGEP}/${CLUSTERDUP}
    echo $I "- Start and Autostart the pool" $O
    virsh pool-start ${CLUSTERDUP}
    virsh pool-autostart ${CLUSTERDUP}

    # Create VOLUMES disk1 disk2 disk3 disk4 disk5 of ${SIZEM}M
    for vol in `seq 1 ${IMAGENB}`
    do
        echo $I "- Create ${diskname}${vol}.img ${SIZEM}M" $O
        virsh vol-create-as --pool ${CLUSTERDUP} --name ${diskname}${vol}.img --format raw --allocation ${SIZEM}M --capacity ${SIZEM}M
    done
}

add_device() {
   echo $I "############ START add_device" $O
   vol="1"
   for i in `seq 1 $NBNODE`
   do
       echo $I "- Attaching disk ${diskname}${vol} from pool ${CLUSTERDUP} to ${NODENAME}${i} (expecting: ${DATA})" $O
       attach_disk_to_node ${NODENAME}${i} ${CLUSTERDUP} ${diskname}${vol} ${DATA} img
       ((vol++))
   done
}

detach_dev_from_node() {
    echo $I "############ START detach_disk_from_node" $O
    for i in `seq 1 $NBNODE`
    do
	detach_disk_from_node ${NODENAME}${i} ${DATA}
    done
}

delete_pool_storage() {
    echo $I "############ START delete_pool_storage"
    echo $W "- Destroy current pool ${CLUSTERDUP}" $O
    virsh pool-destroy ${CLUSTERDUP}
    echo $W "- Undefine current pool ${CLUSTERDUP}" $O
    virsh pool-undefine ${CLUSTERDUP}
    rm -rfv ${STORAGEP}/${CLUSTERDUP}
}

list_devices() {
    echo $I "############ START list_devices" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Devices on node ${NODENAME} ${i}"
	exec_on_node ${NODENAME}${i} "fdisk -l | grep \"^Disk /dev\""
    done
}

format_device() {
    echo $I "############ START format_device" $O
    echo $I "- Format /dev/${DATA} in ext4 and store some date" $O
    exec_on_node ${NODENAME}1 "mkfs.ext4 -v /dev/${DATA}"
    exec_on_node ${NODENAME}1 "mkdir -p ${TESTDIR}" IGNORE=1
    exec_on_node ${NODENAME}1 "mount /dev/${DATA} ${TESTDIR}"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data50M bs=1M count=50"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data150M bs=1M count=150"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data200M bs=1M count=200"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data68M bs=1M count=68"
    exec_on_node ${NODENAME}1 "sync"
    echo $I "- Do some checksum to test after" $O
    exec_on_node ${NODENAME}1 "cd ${TESTDIR} && sha256sum data* > TOCHECK"
    exec_on_node ${NODENAME}1 "cd ${TESTDIR} && cat TOCHECK"
    echo $I "- Umount ${TESTDIR}" $O
    exec_on_node ${NODENAME}1 "umount ${TESTDIR}"
}

##########################
##########################
### MAIN
##########################
##########################

echo $I "############ DUPLICATION TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    repo)
	dolly_add_repo
	;;
    removerepo)
	dolly_remove_repo
	;;
    install)
	install_dolly
	;;
    start)
	start_vm
	;;
    stop)
	stop_vm
	;;
    config)
	config_set
	;;
    runs)
	run_server_dup
	;;
    runc)
	run_duplication
	;;
    configp)
        config_set_plus
        ;;
    pool)
	create_pool_storage
	;;
    device)
	add_device
	;;
    format)
	format_device
	;;
    list)
	list_devices
	;;
    detach)
	detach_dev_from_node
	;;
    deletepool)
	delete_pool_storage
	;;
    cmd)
	cmd_on_nodes $2
	;;
    all)
	echo "too complex ... do manually"
	;;
    *)
	echo "

##########################################
Adjust the VAR if needed:
--------------------------
Cluster name: ${CLUSTER}
Image of VM are stored in : ${STORAGEP}
IDrsa pub key is: ${IDRSA}

UUID: ${UUID}
NODEDOMAIN: ${NODEDOMAIN}
NETWORMNAME (libvirt): ${NETWORKNAME}
IP of the ${NETWORK}
MAC HOST: ${NETMACHOST}
Brdige used: ${BRIDGE}

Nodename: ${NODENAME}

(below modify VAR directly in this script)
Disk added to test duplication: ${DATA}
Disk name: ${diskname}
Dir where disk are stored: ${CLUSTERDUP}
Test dir on nodes: ${TESTDIR}
Size of the image to duplicate in MB: ${SIZEM}

Number of nodes to deploy (clone of node1): ${NBNODE}

################################################

usage of $0 

 repo
	add network:cluster dolly repo (to test latest version)
 
 removerepo
 	remove dolly repo

 install (not mandatory)
	install dolly on all nodes

 start
	start all VM

 stop
	stop all VM

 pool
	create ${CLUSTERDUP} pool and one image per nodes

 device
	add device ${DATA} to all nodes

 format
	format ${DATA} in ext4 and create some files in (on node ${NODENAME}1)

 config (/etc/dolly.cfg)
	prepare the Dolly config file and copy it to all nodes

 list
	list all devices on all nodes (debug devices problem...)
	all devices should use the same name for duplication

 detach
 	detach ${DATA} from all nodes

 deletepool
	delete the pool storage

 cmd
	execute a command on all node (First arg is mandatory)

 runs
	run dolly server on node ${NODENAME}1

 runc
	run dolly client on all nodes (psmisc must be installed !)
	INFO : no more needed as dolly now use systemd socket

"
	;;
esac
