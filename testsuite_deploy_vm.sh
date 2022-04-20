#!/bin/sh
#########################################################
#
#
#########################################################
## INSTALL VM  (and checks)
#########################################################

if [ -f `pwd`/functions ] ; then
    . `pwd`/functions
else
    echo "! need functions in current path; Exiting"; exit 1
fi
check_load_config_file

# global VAR
LIBVIRTPOOL="nodes_images"
DISKVM="${STORAGEP}/vm_xml.raw"
EXTRAARGS="autoyast=device://vdc/vm.xml"

if [ ! -f ${OTHERCDROM} ]; then echo "! ${OTHERCDROM} can not be found, needed for installation! fix this in ${CONF}. Exiting!" ; exit 1; fi
if [ ! -f ${SLECDROM} ]; then echo "! ${SLECDROM} can not be found, needed for installation! fix this in ${CONF}. Exiting!" ; exit 1; fi

# clean up previous VM
cleanup_vm() {
    NAME="${NODENAME}"
    echo $I "############ START cleanup_vm #############"
    echo "  !! WARNING !! "
    echo "  !! WARNING !! " $O
    if [ -d ${STORAGEP}/${LIBVIRTPOOL} ]; then
        echo "- This will remove previous VM guest image (in ${STORAGEP}/${LIBVIRTPOOL} dir)"
        cd ${STORAGEP}/${LIBVIRTPOOL}
        ls -1 ${NAME}*.qcow2
    fi
    echo
    echo " press [ENTER] twice OR Ctrl+C to abort"
    read
    read
    #    for nb in `seq 1 $NBNODE`
    for nb in `seq 1 ${NBNODE}`
    do 
	GNAME="${NAME}${nb}"
	virsh list --all | grep ${GNAME} > /dev/null
	if [ $? == "0" ]; then
    	    echo "- Destroy current VM: ${GNAME}"
    	    virsh destroy ${GNAME}
    	    echo "- Undefine current VM: ${GNAME}"
    	    virsh undefine ${GNAME}
	else
            echo "- ${GNAME} is not present"
	fi
	echo "- Remove previous image file for VM ${GNAME} (${GNAME}.qcow2)"
	rm -rvf ${STORAGEP}/${LIBVIRTPOOL}/${NAME}.qcow2
    done
}

# Install VM 1
install_vm() {
    echo $I "############ START install_vm #############" $O
    # FIRST ARG MUST BE the MAC address
    MAC=$1
    # pool refresh to avoid error
    virsh pool-refresh ${LIBVIRTPOOL}
    echo "- Create new VM guest image file: ${NAME}.qcow2 ${IMAGESIZE}"
    virsh vol-create-as --pool ${LIBVIRTPOOL} --name ${NAME}.qcow2 --capacity ${IMAGESIZE} --allocation ${IMAGESIZE} --format qcow2
    virsh pool-refresh ${LIBVIRTPOOL}
    if [ ! -f ${VMDISK} ]; then echo "- ${VMDISK} NOT present"; exit 1; fi
    echo "- Start VM guest installation in a screen"


    screen -d -m -S "install_VM_guest_${NAME}" virt-install --name ${NAME} \
	   --ram ${RAM} \
	   --vcpus ${VCPU} \
	   --virt-type kvm \
	   --os-variant sles12sp3 \
	   --controller scsi,model=virtio-scsi \
	   --network network=${NETWORKNAME},mac=${MAC} \
	   --graphics vnc,keymap=${KEYMAP} \
	   --disk path=${VMDISK},format=qcow2,bus=virtio,cache=none \
	   --disk path=${SHAREDISK},shareable=on,bus=virtio \
	   --disk path=${DISKVM},shareable=on,bus=virtio \
	   --disk path=${OTHERCDROM},shareable=on,device=cdrom \
	   --disk path=${SLECDROM},shareable=on,device=cdrom \
	   --location ${SLECDROM} \
	   --extra-args ${EXTRAARGS} \
	   --watchdog i6300esb,action=poweroff \
	   --console pty,target_type=virtio \
	   --rng /dev/urandom \
	   --check all=off
}
	  # --boot cdrom \

check_before_install() {
    echo $I "############ START check_before_install #############" $O
    if [ ! -f ${DISKVM} ]; then 
        echo "- ${DISKVM} NOT present, needed for auto installation"; exit 1
    else
        echo "- ${DISKVM} is present"
    fi
    if [ ! -f ${SHAREDISK} ]; then 
        echo "- ${SHAREDISK} NOT present, needed for share device"; exit 1
    else
        echo "- ${SHAREDISK} is present"
    fi
}

copy_ssh_key() {
    echo $I "- Don't forget to copy the root host SSH key to VM guest" $O
    for NB in `seq 1 $NBNODE`
	do
	echo "ssh-copy-id -f -i /root/.ssh/${IDRSA}.pub -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${NODENAME}${NB}"
    done
    echo 
    echo "- Clean up your /root/.ssh/known_hosts from previous config (dirty way below)
    rm -vf /root/.ssh/known_hosts"
}

update_nb_nodes() {
    ((++NBNODE))
    perl -pi -e "s/^NBNODE=.*/NBNODE=${NBNODE}/" $CONF
}

##########################
##########################
### MAIN
##########################
##########################

echo $I "####### PREPARE TO DEPLOY VM #########"
echo "  !! WARNING !! "
echo "  !! WARNING !! "
echo
echo "########################################"$O

case "$1" in
    # CLEAN everything
    cleanup)
	cleanup_vm
	;;
    # create the pool
    pool)
	create_pool ${LIBVIRTPOOL}
	;;
    # verify everything is available
    installvm)
	check_before_install
	# Install VM 1
	NAME="${NODENAME}1"
	VMDISK="${STORAGEP}/${LIBVIRTPOOL}/${NAME}.qcow2"
	MAC=`(echo ${NODENAME}1|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')`
	install_vm ${MAC}
	
	# install all other VM (minimal autoyast file)
	# Use a minimal installation without X for node2 and node3 etc...
	EXTRAARGS="autoyast=device://vdc/vm2.xml"
	
	sleep 1
	for nb in `seq 2 $NBNODE` 
	do
	    # Install VM
	    export NAME="${NODENAME}${nb}"
	    export VMDISK="${STORAGEP}/${LIBVIRTPOOL}/${NAME}.qcow2"
            MAC=`(echo ${NODENAME}${nb}|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')`
	    grep ${MAC} /etc/libvirt/qemu/networks/${NETWORKNAME}.xml
	    if [ "$?" -ne "0" ]; then 
		echo
		echo " !!!! ${MAC} is missing from /etc/libvirt/qemu/networks/${NETWORKNAME}.xml !!!"
		echo " !!!! EXPECT error in IP or Hostname for node ${NODENAME}${nb}"
		echo
		echo " 		PRESS ENTER TO CONTINUE"
		read
	    fi
	    install_vm ${MAC}
	    sleep 1
	done
	;;
    addvm)
	# Install VM
	if [ $# -lt 2 ];
	then 	
	    echo ""
	    echo "! Please enter VM number! Exiting" ; 
	    echo ""
	    echo "Currently VM deployed are:"
	    ls -1 ${STORAGEP}/${LIBVIRTPOOL}/${NAME}*.qcow2
	    exit 1; 
	fi
	export NAME="${NODENAME}${2}"
	export VMDISK="${STORAGEP}/${LIBVIRTPOOL}/${NAME}.qcow2"
        MAC=`(echo ${NODENAME}${2}|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')`
	grep ${MAC} /etc/libvirt/qemu/networks/${NETWORKNAME}.xml
	if [ "$?" -ne "0" ]; then 
	    echo
	    echo " !!!! ${MAC} is missing from network pool /etc/libvirt/qemu/networks/${NETWORKNAME}.xml !!!"
	    echo " !!!! EXPECT error in IP or Hostname for node ${NODENAME}${2}"
	fi
        echo
        echo " 		PRESS ENTER TO CONTINUE AND INSTALL VM ${NODENAME}${2}"
	read
	install_vm ${MAC}
	update_nb_nodes
	echo " You need to re-run some script to add you node in the host config and in the cluster service"
	echo "./testsuite_host_conf.sh ssh"
	echo "./testsuite_host_conf.sh pssh"
	echo "./testsuite_init_cluster.sh hostname
       			scc
		       	munge
			slurm
			nodeslist
			sshkeynode
			testuser

			Dont forget to copy your ssh key id (ie: to node sle15sp35):
	        ssh-copy-id sle15sp35
	
		Edit /root/.ssh/config and add your node in the list, ie:
		host sle15sp31 sle15sp32 sle15sp33 sle15sp34 sle15sp35
		IdentityFile /root/.ssh/id_rsa_SLE
			"
	;;
    info)
	# Check VM
	virsh list
	# Get IP address
	virsh net-dhcp-leases ${NETWORKNAME}
	# List installation in progress
	screen -list
	copy_ssh_key
	;;
    all)
	cleanup
	pool
	installvm
	info	
	;;
    *)
	echo "
	Usage: $0 {cleanup|installvm|addvm|info|pool}

cleanup
	delete all VM and VM storage

pool
	create the pool storage for VM

installvm
	install all VM ($NBNODE)

addvm
	install one more VM (up to $MAXNBNODE)

info
	display info about network, storage, ssh key etc...
"
	exit 1
	;;
esac
