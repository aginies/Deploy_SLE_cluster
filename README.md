# Easily Deploy a cluster of Virtual Machines

The goal was to easily and quickly deploy a cluster of nodes in Virtual
Machine to be able to test latest release and test some scenarios.
This is a semi-automatic script, which means that it will stop on some steps, and it will stop on errors to give you ability to fix the problem if needed.

This scripts will configure:
* an host (by default KVM)
* NB nodes ready (default is 4)

All configurations files on the host are dedicated for this cluster, which means
this should not interact or destroy any other configuration (pool, net, etc...)
This is possible to get multiple instance of cluster from different product/SP, its just
a matter of taking care of path, variable and VM names in the configuration to avoid overlap.

Please report any bugs or improvments to:
https://github.com/aginies/Deploy_SLE_cluster.git

*NOTE*: default root password for Virtual Machine is: "a"

* *WARNING* All guest installation will be done at the same time (5 nodes), time between install is 5 seconds
* *NOTE* You need an other DVD (HA or HPC) and an SLE1XSPX ISO DVD as source for Zypper (optionnal STM/RMT adjusting autoyast file)
* *NOTE* Host server should be a SLE or an openSUSE (script use **zypper**)
* *NOTE* Host server must have PackageHub installed (provides **pssh**)
* *WARNING* Running the script will erase all previous deployment of the same cluster (but not another cluster already deployed)
* *NOTE* Scripts are written in shell to simplify external contribution and modification, of course this choice lead to some technical limitation but the main advantage is to be able to deploy it quickly on any kind of product without any missing dependencies.

## Install / HOWTO

* Clone this repository
* You must be root to use this scripts
* Adjust VARS in **vm.conf** file (or create a link from your configuration to this link)
* Create **SCCDATA.conf** file and populate it, ie:
	SCCREGCODE=YOUR_SCC_REG_CODE
	VERSION=15.3
1. Prepare the host: **testsuite_host_conf.sh**
2. Deploy VM: **testsuite_deploy_vm.sh**
3. Init the cluster: **testsuite_init_cluster.sh**
* Your cluster is now able to run some scenarios, go in scenarios and launch one
4. optionnal **testsuite_control_cluster.sh** can help you to do some redundant tasks on the cluster

## vm.conf configuration file
All variables for VM guest and Host. Most of them should not be changed.

*NOTE*:
You should adjust path to ISO for installation. Currently this is using local or NFS ISO via a pool.
* OTHERCDROM="/var/lib/libvirt/images/SLE-12-SP2-HA-DVD-x86_64-Buildxxxx-Media1.iso"
* SLECDROM="/var/lib/libvirt/images/SLE-12-SP2-Server-DVD-x86_64-Buildxxxx-Media1.iso"

If you want to specify another way to ISO (like http etc...) you maybe need to adjust
install_vm() function in testsuite_deploy_vm.sh script.

## Scripts

### testsuite_host_conf.sh
Configure the host:
* install virtualization tools and restart libvirtd (disable by default)
* generate an ssh root key, and prepare a config to connect to nodes
* add nodes in **/etc/hosts**
* create a Virtual Network: DHCP with host/mac/name/ip for nodes
* create a SHARED pool
* prepare an image (raw) which contains autoyast file

### testsuite_deploy_vm.sh
This script will install all nodes with needed data
* clean-up all previous data: VM definition, VM images
* create a slepool to store VM images
* install all VM (using a screen)
* display information how to copy host root key to nodes (VM)

**Warning** A classical issue while deploying VM could be the virtual network.
Run the script like this to debug:
```
bash -x testsuite_deploy_vm.sh
```

If no VM start to install, grab the **virt-install** command line and paste it 
into a root console:
```
linux-5530:~/github/Deploy_SLE_cluster #  virt-install --name sle15sp31 --ram 4096 --vcpus 2 --virt-type kvm --os-variant sles12sp3 --controller scsi,model=virtio-scsi --network network=slehpcsp3,mac=02:89:89:85:05:a1 --graphics vnc,keymap=fr --disk path=/data/TEST/images/sle15sp3/nodes_images/sle15sp31.qcow2,format=qcow2,bus=virtio,cache=none --disk path=/data/TEST/images/sle15sp3/commondisk/commondisk.img,shareable=on,bus=virtio --disk path=/data/TEST/images/sle15sp3/vm_xml.raw,shareable=on,bus=virtio --disk path=,shareable=on,device=cdrom --disk path=/data/ISO/SLE-15-SP3-Full-x86_64-Buildxxxxx-Media1.iso,shareable=on,device=cdrom --location /data/ISO/SLE-15-SP3-Full-x86_64-Buildxxxxx-Media1.iso --extra-args autoyast=device://vdc/vm.xml --watchdog i6300esb,action=poweroff --console pty,target_type=virtio --rng /dev/urandom --check all=off 
Setting input-charset to 'UTF-8' from locale.
WARNING  Graphics requested but DISPLAY is not set. Not running virt-viewer.
WARNING  No console to launch for the guest, defaulting to --wait -1

Starting install...
Setting input-charset to 'UTF-8' from locale.
Retrieving file linux...                                                                     | 8.6 MB  00:00:00     
Setting input-charset to 'UTF-8' from locale.
Retrieving file initrd...                                                                    |  99 MB  00:00:00     
ERROR    Network not found: no network with matching name 'slehpcsp3'
Domain installation does not appear to have been successful.
If it was, you can restart your domain by running:
  virsh --connect qemu:///system start sle15sp31
otherwise, please restart your installation.
```

You can see the:
```
ERROR    Network not found: no network with matching name 'slehpcsp3'
```

Run the **testsuite_host_conf.sh** with **bash -x** to find the issue:
```
bash -x testsuite_host_conf.sh virtualnet
```

### testsuite_init_cluster.sh
Finish the nodes installation and run some tests.


## AutoYast files

Files used for auto-installation of nodes. Files are copied into
a image file (**vm_xml.raw**) and used as a disk image under VM.

### vm.xml
This file is the autoyast profile with some other tools.

### vm_mini.xml
This file is the autoyast profile (simple without GUI/X).

## functions
Contains needed functions for all scripts.


### scenarios directory
This directory contains some scenarios you can run on you cluster to test it.
