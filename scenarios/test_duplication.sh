#!/bin/sh
#########################################################
#
#
#########################################################
## DUPLICATION TEST
#########################################################

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

DEVNAME="vdf"
diskname="disk"
CLUSTERDUP="CLUSTERDUP"
TESTDIR="/mnt/test/"
# size of the image to duplicate
SIZEM="512"
IMAGENB=${NBNODE}

# BIG CLUSTER CONFIG !
#IMAGENB=30
#NODENAME=dolly
#NBNODE=30
#

prepare_duplication() {
    echo $I "############ START prepare_duplication" $O
    echo $I "-Install all tools on all nodes" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Node ${NODENAME}${i}:"
        scp_on_node "../packages/*.rpm" "test@${NODENAME}${i}:/tmp/"
	exec_on_node ${NODENAME}${i} "zypper in -y screen"
	exec_on_node ${NODENAME}${i} "zypper in --allow-unsigned-rpm -y  /tmp/dolly*.rpm"
    done
}

run_duplication() {
   echo $I "############ START run_duplication" $O
   echo $I "- Start server on node ${NODENAME}1" $O
   exec_on_node ${NODENAME}1 "screen -S dollyServer \"dolly -v -s -f /etc/dolly.cfg\""
   echo $I "- Start client on all other nodes" $O
   for i in `seq 2 $NBNODE`
   do
	exec_on_node ${NODENAME}${i} "screen -S dollyClient \"dolly -v -f /etc/dolly.cfg\""
   done
}

config_set() {
   echo $I "############ START config_set" $O
   cat > dolly.cfg <<EOF
infile /dev/${DEVNAME}
outfile /dev/${DEVNAME}
server ${NODENAME}1
firstclient ${NODENAME}1
lastclient ${NODENAME}${NBNODE}
clients ${NBNODE}"
EOF
for i in `seq 2 $NBNODE`
do
echo "${NODENAME}${NBNODE}" >> dolly.cfg
done
echo "endconfig" >> dolly.cfg

	for i in `seq 1 $NBNODE`
	do
		scp_on_node dolly.cfg "root@${NODENAME}${i}:/etc/"
	done
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

delete_pool_storage() {
    echo $I "############ START delete_pool_storage"
    echo $W "- Destroy current pool ${CLUSTERDUP}" $O
    virsh pool-destroy ${CLUSTERDUP}
    echo $W "- Undefine current pool ${CLUSTERDUP}" $O
    virsh pool-undefine ${CLUSTERDUP}
    rm -rfv ${STORAGEP}/${CLUSTERDUP}
}


add_device() {
   echo $I "############ START add_device" $O
   vol="1"
   for i in `seq 1 $NBNODE`
	do
	echo $I "- Attaching disk ${diskname}${vol} from pool ${CLUSTERDUP} to ${NODENAME}${i} (expecting: /dev/${DEVNAME})" $O
	attach_disk_to_node ${NODENAME}${i} ${CLUSTERDUP} ${diskname}${vol} ${DEVNAME} img
	((vol++))
   done
}

detach_dev_from_node() {
   echo $I "############ START detach_disk_from_node" $O
   for i in `seq 1 $NBNODE`
   do
	detach_disk_from_node ${NODENAME}${i} ${DEVNAME}
   done
}


list_devices() {
   echo $I "############ START list_devices" $O
   for i in `seq 1 $NBNODE`
   do
	echo "- Devices on node ${NODENAME} ${i}"
	exec_on_node ${NODENAME}${i} "fdisk -l | grep \"^/dev\""
   done
}

format_device() {
   echo $I "############ START format_device" $O
   echo $I "- Format /dev/${DEVNAME} in ext4 and store some date" $0
   exec_on_node ${NODENAME}1 "mkfs.ext4 -v /dev/${DEVNAME}"
   exec_on_node ${NODENAME}1 "mkdir -p ${TESTDIR}" IGNORE=1
   exec_on_node ${NODENAME}1 "mount /dev/${DEVNAME} ${TESTDIR}"
   exec_on_node ${NODENAME}1 "cp -av /tmp/*.rpm ${TESTDIR}"
   echo $I "- Do some checksum to test after" $0
   exec_on_node ${NODENAME}1 "cd ${TESTDIR} && sha256sum *.rpm > TOCHEK"
   echo $I "- Umount ${TESTDIR}" $0
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
    run)
	run_duplication
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
    config)
	config_set
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
    all)
	echo "too complex ... do manually"
	;;
    *)
	echo "
usage of $0 {prepare|pool|device|format|config|deletepool|run|list|all}

 prepare
	install all needed on all nodes

 pool
	create pool and image for nodes 

 device
	add device ${DEVNAME} to all nodes

 format
	format ${DEVNAME} and write some files in

 config
	prepare the config file

  list
	list all devices on all nodes

 detach
 	detach ${DEVNAME} from all nodes

 deletepool
	delete the pool storage

 run
	run the test 

"
	;;
esac
