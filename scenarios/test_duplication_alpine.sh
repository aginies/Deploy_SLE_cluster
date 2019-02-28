#!/bin/sh
#########################################################
#
#
#########################################################
## DUPLICATION TEST ON ALPINE OS
#########################################################
#
# USE https://wiki.alpinelinux.org/wiki/Installation
# image: https://www.alpinelinux.org/downloads/ (choose virt one)
## SSHD: /etc/ssh/sshd_config
# PermitRootLogin yes
# PermitEmptyPasswords yes
# /etc/inut.d/sshd restart
## SERVICE:
# chmod 644 /etc/init.d/chronyd
# chmod 644 /etc/init.d/crond
#
## Install package to be able to build dolly:
# apk add build-base
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


CLUSTER="duplication"
STORAGEP="/mnt/data/libvirt/images/duplication"
IDRSA="id_rsa_DUPLICATION"

UUID="951e50f1-db73-475a-895f-34562baf8e8f"
NODEDOMAIN="duplication.com"
NETWORKNAME="duplication"
NETWORK="192.168.222"
NETMACHOST="52:54:00:89:b0:C9"
BRIDGE="vibr2"

NODENAME="alpine"
DEVNAME="vdb"
diskname="disk"
CLUSTERDUP="DUP"
TESTDIR="/mnt/test"
# size of the image to duplicate (in MB)
SIZEM="512"

# BIG CLUSTER CONFIG !
NBNODE=35
IMAGENB=${NBNODE}


# ADD node to /etc/hosts (hosts)
prepare_etc_hosts() {
    echo $I "############ START prepare_etc_hosts #############" $O
    grep ${NODENAME}1.${NODEDOMAIN} /etc/hosts
    if [ $? == "1" ]; then
        echo "- Prepare /etc/hosts (adding nodes)"
        CURRENT=0
        for i in `seq 1 $NBNODE`
        do
            ((++CURRENT))
            if [ ${CURRENT} -lt "10" ]; then
                echo "${NETWORK}.10${i}  ${NODENAME}${i}.${NODEDOMAIN} ${NODENAME}${i}" >> /etc/hosts
            else
                echo "${NETWORK}.1${i}  ${NODENAME}${i}.${NODEDOMAIN} ${NODENAME}${i}" >> /etc/hosts
            fi
        done
    else
        echo "- /etc/hosts already ok"
    fi
}

# Define net private network (NAT)
# NETWORK will be ${NETWORK}.0/24 gw/dns ${NETWORK}.1
prepare_virtual_network() {
    echo $I "############ START prepare_virtual_network #############"
    echo "- Prepare virtual network (/etc/libvirt/qemu/networks/${NETWORKNAME}.xml)" $O
    cat > /etc/libvirt/qemu/networks/${NETWORKNAME}.xml << EOF
<network>
  <name>${NETWORKNAME}</name>
  <uuid>${UUID}</uuid>
  <forward mode='nat'/>
  <bridge name='${BRIDGE}' stp='on' delay='0'/>
  <mac address='${NETMACHOST}'/>
  <domain name='${NETWORKNAME}'/>
  <ip address='${NETWORK}.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='${NETWORK}.188' end='${NETWORK}.254'/>
EOF
    CURRENT=0
    for i in `seq 1 $NBNODE`
    do
        ((++CURRENT))
        MAC=`(echo ${NODENAME}${CURRENT}|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')`
        if [ ${CURRENT} -lt "10" ]; then
            echo "<host mac=\"${MAC}\" name=\"${NODENAME}${CURRENT}.${NODEDOMAIN}\" ip=\"${NETWORK}.10${CURRENT}\" />" >> /etc/libvirt/qemu/networks/${NETWORKNAME}.xml
        else
            echo "<host mac=\"${MAC}\" name=\"${NODENAME}${CURRENT}.${NODEDOMAIN}\" ip=\"${NETWORK}.1${CURRENT}\" />" >> /etc/libvirt/qemu/networks/${NETWORKNAME}.xml
        fi
    done
    echo "    </dhcp>
  </ip>
</network>" >> /etc/libvirt/qemu/networks/${NETWORKNAME}.xml

    echo "- Start ${NETWORKNAME}"
    systemctl restart libvirtd
    virsh net-destroy ${NETWORKNAME}
    virsh net-autostart ${NETWORKNAME}
    virsh net-start ${NETWORKNAME}
}

# ssh root key on host
# should be without password to speed up command on NODE
ssh_root_key() {
    echo $i "############ START ssh_root_key #############"
    echo "- Generate ~/.ssh/${IDRSA} without password" $O
    ssh-keygen -t rsa -f ~/.ssh/${IDRSA} -N ""
    echo "- Create /root/.ssh/config for nodes access"
    CONFIGSSH="/root/.ssh/config"
    TMPF="/tmp/host_config_CLUSTER"
    grep ${NODENAME}2 $CONFIGSSH
    if [ "$?" -ne "0" ]; then
        for i in `seq 1 ${NBNODE}`
        do
                echo -n "${NODENAME}${i} " >> ${TMPF}
        done
        echo host `cat ${TMPF}` >> $CONFIGSSH
        echo "IdentityFile /root/.ssh/${IDRSA}" >> $CONFIGSSH
    else
        echo "- seems $CONFIGSSH already contains needed modification"
    fi
    rm -f ${TMPF}
}

copy_ssh_key() {
    echo $I "- Don't forget to copy the root host SSH key to VM guest" $O
    for NB in `seq 1 $NBNODE`
	do
	echo "ssh-copy-id -f -i /root/.ssh/${IDRSA}.pub -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${NODENAME}${NB}"
    done
    echo 
    echo "- Clean up your /root/.ssh/known_hosts from previous config (dirty way below)"
    rm -vf /root/.ssh/known_hosts
}



prepare_duplication() {
    echo $I "############ START prepare_duplication" $O
    echo $I "-Install all tools on all nodes" $O
    for i in `seq 1 $NBNODE`
    do
	echo "- Node ${NODENAME}${i}:"
        scp_on_node "dolly" "root@${NODENAME}${i}:/tmp/"
    done
}

run_server_dup() {
  echo $I "############ START run_server_dup" $O
  echo $I "- Start server on node ${NODENAME}1" $O
  echo "ssh ${NODENAME}1 \"screen -d -m /root/dolly -s -v -o /root/dolly.log -f /etc/dolly.cfg\""
  ssh ${NODENAME}1 "screen -d -m /root/dolly -s -v -f /etc/dolly.cfg"
}

run_duplication() {
   echo $I "############ START run_duplication" $O
   echo $I "- Start client on all other nodes" $O
   for i in `seq 2 $NBNODE`
   do
	echo "- Killall -9 dolly on nodes ${NODENAME}${i} in case off..."
	ssh ${NODENAME}${i} "killall -9 dolly"
	echo "ssh ${NODENAME}${i} \"screen -d -m /root/dolly -v -f /etc/dolly.cfg\""
	ssh ${NODENAME}${i} "screen -d -m /root/dolly -v -f /etc/dolly.cfg"
	sleep 1
   done
}

config_set() {
   echo $I "############ START config_set" $O
   CLIENTS=`echo $((${NBNODE}-1))`
   cat > dolly.cfg <<EOF
infile /dev/${DEVNAME}
outfile /dev/${DEVNAME}
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

	for i in `seq 1 $NBNODE`
	do
		scp_on_node dolly.cfg "root@${NODENAME}${i}:/etc/"
	done
	echo "- CONFIGURATION:"
	echo "################"
	cat dolly.cfg
	echo "################"
	rm dolly.cfg
}

clone_vm() {
    echo $I "############ START clone_vm" $O
    ORIGIN=${NODENAME}1
    for i in `seq 2 $NBNODE`
    do
	MAC=`(echo ${NODENAME}${i}|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')`
	echo "- ${NODENAME}${i} ${STORAGEP}/nodes_images/${NODENAME}${i} ${MAC}"
	virt-clone --original ${NODENAME}1 --name ${NODENAME}${i} --file ${STORAGEP}/nodes_images/${NODENAME}${i}.qcow2 --mac ${MAC}
    done
}

delete_vm() {
    echo $I "############ START delete_vm" $O
    echo
    echo $I "!! PLEASE ENTER TWICE TO CONFIRM! " $O
    read
    read
    stop_vm
    for i in `seq 2 $NBNODE`
    do
	echo "- Undefine ${NODENAME}${i}"
	virsh undefine ${NODENAME}${i}
	echo "- Deleting storage for ${NODENAME}${i}"
	rm -v ${STORAGEP}/nodes_images/${NODENAME}${i}.qcow2
    done
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


fix_hostname() {
    echo $I "############ START fix_hostname" $O
    for i in `seq 1 $NBNODE`
    do
        exec_on_node ${NODENAME}${i} "echo ${NODENAME}${i} > /etc/hostname"
	exec_on_node ${NODENAME}${i} "hostname ${NODENAME}${i}"
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
	exec_on_node ${NODENAME}${i} "fdisk -l | grep \"^Disk /dev\""
    done
}

format_device() {
    echo $I "############ START format_device" $O
    echo $I "- Format /dev/${DEVNAME} in ext4 and store some date" $0
    exec_on_node ${NODENAME}1 "mkfs.ext4 -v /dev/${DEVNAME}"
    exec_on_node ${NODENAME}1 "mkdir -p ${TESTDIR}" IGNORE=1
    exec_on_node ${NODENAME}1 "mount /dev/${DEVNAME} ${TESTDIR}"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data50M bs=1M count=50"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data150M bs=1M count=150"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data200M bs=1M count=200"
    exec_on_node ${NODENAME}1 "dd if=/dev/zero of=${TESTDIR}/data68M bs=1M count=68"
    exec_on_node ${NODENAME}1 "sync"
    echo $I "- Do some checksum to test after" $0
    exec_on_node ${NODENAME}1 "cd ${TESTDIR} && sha256sum data* > TOCHECK"
    exec_on_node ${NODENAME}1 "cd ${TESTDIR} && cat TOCHECK"
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
    ssh)
        ssh_root_key
        ;;
    copyssh)
	copy_ssh_key
	;;
    etchosts)
        prepare_etc_hosts
        ;;
    clone)
	clone_vm
	;;
    deletevm)
	delete_vm
	;;
    start)
	start_vm
	;;
    stop)
	stop_vm
	;;
    fixhost)
	fix_hostname
	;;
    virtualnet)
        prepare_virtual_network
        ;;
    runs)
	run_server_dup
	;;
    runc)
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
Disk added to test duplication: ${DEVNAME}
Disk name: ${diskname}
Dir where disk are stored: ${CLUSTERDUP}
Test dir on nodes: ${TESTDIR}
size of the image to duplicate in MB: ${SIZEM}

Number of nodes to deploy (clone of node1): ${NBNODE}

################################################
INFO : Default root pass on Alpine VM is empty
################################################

usage of $0 {prepare|ssh|clone|etchosts|fixhost|virtualnet|pool|device|format|config|deletepool|start|stop|runs|runc|list|deletevm|all}

 prepare (no mandatory)
	copy dolly on all nodes (no needed with alpine VM)

 ssh (not mandatory)
	generate an ssh root key, and prepare a config to connect to nodes

 virtualnet
	create a Virtual Network: DHCP with host/mac/name/ip for nodes

 copyssh (not mandatory)
	copy ssh root key to all nodes

 etchosts
	add nodes in /etc/hosts

 clone
	clone ${NODENAME}1 to ${NBNODE}
 
 deletevm (to restart from scratch)
	delete all VM (NOT the ${NODENAME}1!)
	deleta also the image file (${STORAGEP}/nodes_images/${NODENAME}X)

 start
	start all VM

 stop
	stop all VM

 fixhost
	fix hostname on all VM

 pool
	create pool and image for nodes 

 device
	add device ${DEVNAME} to all nodes (/dev/${DEVNAME})

 format
	format ${DEVNAME} and write some files in (on node ${NODENAME}1)

 config (/etc/dolly.cfg)
	prepare the Dolly config file and copy it to all nodes

 list
	list all devices on all nodes (debug devices problem...)

 detach
 	detach ${DEVNAME} from all nodes

 deletepool
	delete the pool storage

 runs
	run dolly server on node ${NODENAME}1

 runc
	run dolly client on all nodes the test

"
	;;
esac
