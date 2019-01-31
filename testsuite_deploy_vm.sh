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
    for nb in `seq 1 9`
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
	   --graphics vnc,keymap=${KEYMAP} \
	   --network network=${NETWORKNAME},mac=${MAC}${ENDNODEMAC} \
	   --disk path=${VMDISK},format=qcow2,bus=virtio,cache=none \
	   --disk path=${SHAREDISK},bus=virtio \
	   --disk path=${DISKVM},bus=virtio \
	   --disk path=${OTHERCDROM},device=cdrom \
	   --disk path=${SLECDROM},device=cdrom \
	   --location ${SLECDROM} \
	   --boot cdrom \
	   --extra-args ${EXTRAARGS} \
	   --watchdog i6300esb,action=poweroff \
	   --console pty,target_type=virtio \
	   --check all=off
}

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

##########################
##########################
### MAIN
##########################
##########################

# CLEAN everything
cleanup_vm

# create the pool
create_pool ${LIBVIRTPOOL}

# verify everything is available
check_before_install

# Install VM 1
NAME="${NODENAME}1"
ENDNODEMAC="1"
VMDISK="${STORAGEP}/${LIBVIRTPOOL}/${NAME}.qcow2"
install_vm

# install all other VM (minimal autoyast file)
# Use a minimal installation without X for node2 and node3 etc...
EXTRAARGS="autoyast=device://vdc/vm_mini.xml"

for nb in `seq 2 $NBNODE` 
	do
	# Install VM 
	export NAME="${NODENAME}${nb}"
	export ENDNODEMAC=${nb}
	export VMDISK="${STORAGEP}/${LIBVIRTPOOL}/${NAME}.qcow2"
	sleep 5
	install_vm
done

# Check VM
virsh list --all

# Get IP address
virsh net-dhcp-leases ${NETWORKNAME}

# List installation in progress
screen -list

copy_ssh_key


#EXTRA_SCRIPT_AFTER_INSTALL
