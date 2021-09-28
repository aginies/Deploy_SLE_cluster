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
SIZEM="15120"

# BIG CLUSTER CONFIG !
NBNODE=3
IMAGENB=${NBNODE}


prepare_duplication() {
    echo $I "############ START prepare_duplication" $O
    echo $I "-Install all tools on all nodes" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Node ${NODENAME}${i}:"
        scp_on_node "dolly" "root@${NODENAME}${i}:/usr/bin/"
    done
}

run_server_dup() {
  echo $I "############ START run_server_dup" $O
  echo $I "- Start server on node ${NODENAME}1" $O
  echo "- Manual Launch:"
  echo "ssh ${NODENAME}1"
  echo "dolly -s -v -o /root/dolly.log -f /etc/dolly.cfg"
  echo
  echo "- Using Screen:"
  echo "ssh ${NODENAME}1 \"screen -d -m dolly -s -v -o /root/dolly.log -f /etc/dolly.cfg\""
  echo
  echo " PRESS ENTER TWICE TO LAUNCH IT"
  read
  read
  ssh ${NODENAME}1 "screen -d -m dolly -s -v -f /etc/dolly.cfg"
}

run_server_dup_plus() {
  echo $I "############ START run_server_dup_plus" $O
  echo $I "- Start server on node ${NODENAME}1" $O
  echo "- Manual Launch:"
  echo "ssh ${NODENAME}1"
  echo "dollyS -v -f /etc/dollyplus.cfg"
  echo
  echo "- Using Screen:"
  echo "ssh ${NODENAME}1 \"screen -d -m dollyS -v -f /etc/dollyplus.cfg\""
  echo
  echo " PRESS ENTER TWICE TO LAUNCH IT"
  read
  read
  ssh ${NODENAME}1 "screen -d -m dollyS -v -f /etc/dollyplus.cfg"
}


run_duplication() {
   echo $I "############ START run_duplication" $O
   echo $I "- Start client on all other nodes" $O
   for i in `seq 2 $NBNODE`
   do
	echo "- Killall -9 dolly on nodes ${NODENAME}${i} in case off..."
	ssh ${NODENAME}${i} "killall -9 dolly"
	echo "ssh ${NODENAME}${i} \"screen -d -m dolly -v\""
	ssh ${NODENAME}${i} "screen -d -m dolly -v"
	sleep 1
   done
}

run_duplication_plus() {
   echo $I "############ START run_duplication_plus" $O
   echo $I "- Start client on all other nodes" $O
   for i in `seq 2 $NBNODE`
   do
	echo "- Killall -9 dollyC on nodes ${NODENAME}${i} in case off..."
	ssh ${NODENAME}${i} "killall -9 dollyC"
	echo "ssh ${NODENAME}${i} \"screen -d -m dollyC -v\""
	ssh ${NODENAME}${i} "screen -d -m dollyC"
	sleep 1
   done
}

config_set_plus() {
   echo $I "############ START config_set_plus" $O
   CLIENTS=`echo $((${NBNODE}-1))`
   cat > dollyplus.cfg <<EOF
iofiles 1
/dev/${DATA} > /dev/$DATA
server ${NODENAME}1
firstclient ${NODENAME}2
lastclient ${NODENAME}${NBNODE}
clients ${CLIENTS}
EOF
for i in `seq 2 $NBNODE`
do
echo "${NODENAME}${i}" >> dollyplus.cfg
done
echo "endconfig" >> dollyplus.cfg

scp_on_node dollyplus.cfg "root@${NODENAME}1:/etc/"
echo "- CONFIGURATION:"
echo "################"
cat dollyplus.cfg
echo "################"
rm dollyplus.cfg
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

start_vm() {
    echo $I "############ START start_vm" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Starting domain ${NODENAME}${i}"
	virsh start ${NODENAME}${i}
	sleep 2
    done
}

stop_vm() {
    echo $I "############ START stop_vm" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Stoping domain ${NODENAME}${i}"
	virsh destroy ${NODENAME}${i}
	sleep 1
    done
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

cmd_on_nodes() {
    echo $I "############ START cmd" $O
    if [ -z "$1" ]; then echo "- First arg must be the command!"; exit 1; fi
    CMD="$1"
    for i in `seq 1 $NBNODE`
    do
        eec_on_node ${NODENAME}${i} "$CMD"
    done
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
    prepare)
	prepare_duplication
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
    runsp)
        run_server_dup_plus
        ;;
    runcp)
        run_duplication_plus
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
    cmd)
	cmd_on_nodes $2
	;;
    detach)
	detach_dev_from_node
	;;
    deletepool)
	delete_pool_storage
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
Disk added to test duplication: ${DATA}
Disk name: ${diskname}
Dir where disk are stored: ${CLUSTERDUP}
Test dir on nodes: ${TESTDIR}
Size of the image to duplicate in MB: ${SIZEM}

Number of nodes to deploy (clone of node1): ${NBNODE}

################################################
INFO : Default root pass on Alpine VM is empty
################################################

usage of $0 

 prepare (no mandatory)
	copy dolly on all nodes (no needed with alpine VM)

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

 configp (/etc/dollyplus.cfg)
	prepare the Dolly++ config file and copy it to all nodes

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
	run dolly client on all nodes

 runsp
	run dollyS server on node ${NODENAME}1

 runcp
	run dollyC client on all nodes

"
	;;
esac
