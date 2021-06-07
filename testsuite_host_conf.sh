#!/bin/sh
#########################################################
#
#
#########################################################
## HOST CONFIGURATION
#########################################################

# ie: ISO as source of RPM:
#zypper addrepo "iso:/?iso=SLE-12-SP2-Server-DVD-x86_64-Buildxxxx-Media1.iso&url=nfs://10.0.1.99/volume1/install/ISO/SP2devel/" ISOSLE
#zypper addrepo "iso:/?iso=SLE-12-SP2-HA-DVD-x86_64-Buildxxxx-Media1.iso&url=nfs://10.0.1.99/volume1/install/ISO/SP2devel/" ISOHA

if [ -f `pwd`/functions ] ; then
    . `pwd`/functions
else
    echo "! need functions in current path; Exiting"; exit 1
fi
check_load_config_file


# Install all needed Hypervisors tools
install_virtualization_stack() {
    echo $I "############ START install_virtualization_stack #############"
    echo "- patterns-sles-${HYPERVISOR}_server patterns-sles-${HYPERVISOR}_tools and restart libvirtd" $O
    zypper in -y patterns-sles-${HYPERVISOR}_server
    zypper in -y patterns-sles-${HYPERVISOR}_tools
    echo "- Restart libvirtd"
    systemctl restart libvirtd
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

# Connect as root in VMguest without Password, copy root host key
# pssh will be used
# Command from Host
prepare_remote_pssh() {
    echo $I "############ START prepare_remote_pssh #############"
    echo "- Install pssh and create ${PSSHCONF}" $O
    zypper in -y pssh
    echo ${NODENAME}1 > ${PSSHCONF}
    for i in `seq 2 $NBNODE`
	do
    	echo ${NODENAME}${i} >> ${PSSHCONF}
    done
    echo "- usage:" $O
    echo "pssh -h ${PSSHCONF} [command]" $O
}

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

# Create an SHARE pool on the host 
prepare_SHARE_pool() {
    echo $I "############ START prepare_SHARE_pool" $O
# Create a shared pool 
    virsh pool-list --all | grep ${SHARENAME} > /dev/null
    if [ $? == "0" ]; then
    	echo "- Destroy current pool ${SHARENAME}"
    	virsh pool-destroy ${SHARENAME}
    	echo "- Undefine current pool ${SHARENAME}"
    	virsh pool-undefine ${SHARENAME}
        rm -vf ${SHAREDISK}
    else
        echo "- ${SHARENAME} pool is not present"
    fi
    echo "- Define pool ${SHARENAME}"
    mkdir -p ${STORAGEP}/${SHARENAME}
    virsh pool-define-as --name ${SHARENAME} --type dir --target ${STORAGEP}/${SHARENAME}
    echo "- Start and Autostart the pool"
    virsh pool-start ${SHARENAME}
    virsh pool-autostart ${SHARENAME}

# Create the VOLUME SHARE.img
    echo "- Create ${SHARENAME}.img ${SHARENAME}"
    virsh vol-create-as --pool ${SHARENAME} --name ${SHARENAME}.img --format raw --allocation 10M --capacity 10M
}

# Create a RAW file which contains auto install file for deployment
prepare_auto_deploy_image() {
    echo $I "############ START prepare_auto_deploy_image #############"
    echo "- Prepare the autoyast image for VM guest installation (vm_xml.raw)" $O
    WDIR=`pwd`
    WDIR2="/tmp/tmp_sle"
    WDIRMOUNT="/mnt/tmp_sle"
    mkdir ${WDIRMOUNT} ${WDIR2}
    cd ${STORAGEP}
    cp -avf ${WDIR}/${VMXML} ${WDIR2}/vm.xml
    cp -avf ${WDIR}/${VMMINIXML} ${WDIR2}/vm2.xml
    sleep 1
    perl -pi -e "s/NETWORK/${NETWORK}/g" ${WDIR2}/vm.xml
    perl -pi -e "s/NODEDOMAIN/${NODEDOMAIN}/g" ${WDIR2}/vm.xml
    perl -pi -e "s/NODENAME/${NODENAME}/g" ${WDIR2}/vm.xml
    perl -pi -e "s/FHN/${NODENAME}/g" ${WDIR2}/vm.xml
    perl -pi -e "s/NETWORK/${NETWORK}/g" ${WDIR2}/vm2.xml
    perl -pi -e "s/NODEDOMAIN/${NODEDOMAIN}/g" ${WDIR2}/vm2.xml
    perl -pi -e "s/NODENAME/${NODENAME}/g" ${WDIR2}/vm2.xml
    perl -pi -e "s/FHN/${NODENAME}/g" ${WDIR2}/vm2.xml
    qemu-img create vm_xml.raw -f raw 2M
    mkfs.ext3 vm_xml.raw
    mount vm_xml.raw ${WDIRMOUNT}
    cp -v ${WDIR2}/vm.xml ${WDIRMOUNT}
    cp -v ${WDIR2}/vm2.xml ${WDIRMOUNT}
    umount ${WDIRMOUNT}
    rm -rf ${WDIRMOUNT} ${WDIR2}
}

check_host_config() {
    echo $I "############ START check_host_config #############"
    echo "- Show net-list" $O
    virsh net-list
    echo "- Display pool available"
    virsh pool-list
    echo "- List volume available in ${SHARENAME}"
    virsh vol-list ${SHARENAME}
}

###########################
###########################
#### MAIN
###########################
###########################

echo $I "############ PREPARE HOST #############"
echo "  !! WARNING !! "
echo "  !! WARNING !! "
echo 
echo "  This will remove any previous Host configuration for VM guests and testing"
echo
echo "########################################"$O

case "$1" in
    ssh)
        ssh_root_key
        ;;
    vtstack)
	install_virtualization_stack
        ;;
    pssh)
	prepare_remote_pssh
	;;
    etchosts)
	prepare_etc_hosts
	;;
    virtualnet)
	prepare_virtual_network
	;;
    SHAREpool)
	prepare_SHARE_pool
	;;
    autoyastimage)
	prepare_auto_deploy_image
	;;
    all)
	ssh_root_key
	#install_virtualization_stack
	#prepare_remote_pssh
	prepare_etc_hosts
	prepare_virtual_network
	prepare_SHARE_pool
	prepare_auto_deploy_image
	check_host_config
        ;;
    *)
        echo "
     Usage: $0 {ssh|pssh|vtstack|etchosts|virtualnet|SHAREpool|autoyastimage|all}
     
 vtstack
    install virtualization tools and restart libvirtd

 ssh
    generate an ssh root key, and prepare a config to connect to nodes

 pssh
    Install pssh and create ${PSSHCONF}

 etchosts
    add nodes in /etc/hosts

 virtualnet
    create a Virtual Network: DHCP with host/mac/name/ip for nodes
    (/etc/libvirt/qemu/networks/${NETWORKNAME}.xml)

 SHAREpool
    create an SHARED pool (needed to share Images to all nodes)
    (${STORAGEP}/${SHARENAME})

 autoyastimage
    prepare an image (raw) which contains autoyast file

"
exit 1
esac
