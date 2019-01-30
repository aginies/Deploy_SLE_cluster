# Easily Deploy a cluster of Virtual Machines

The goal was to easily and quickly deploy a cluster of nodes in Virtual
Machine to be able to test latest release and test some scenarios.
This is a semi-automatic script, which means that it will stop on some steps, and it will stop on errors to give
you ability to fix the problem if needed.

This scripts will configure:
* an host (by default KVM)
* 6 nodes ready

All configurations files on the host are dedicated for this cluster, which means
this should not interact or destroy any other configuration (pool, net, etc...)
This is possible to get multiple instance of cluster from different product/SP, its just 
a matter of taking care of path, variable and VM names in the configuration to avoid overlap.

Please report any bugs or improvments to:
https://github.com/aginies/Deploy_SLE_cluster.git

*NOTE*: default root password for Virtual Machine is: "a"

* *WARNING* All guest installation will be done at the same time (6 nodes), time between install is 5 seconds
* *NOTE* You need an other DVD rom and an SLE1XSPX ISO DVD as source for Zypper (optionnal STM/RMT adjusting autoyast file)
* *NOTE* Host server should be a SLE or an openSUSE (will use zypper)
* *WARNING* Running the script will erase all previous deployment of the same cluster (but not another cluster deployed)
* *NOTE* Scripts are written in shell to simplify external contribution and modification, of course this choice lead to some technical limitation but the main advantage is to be able to deploy it quickly on any kind of product without any missing dependencies

## Install / HOWTO

* Clone this repository
* Adjust VARS in vm.conf file (or create a link from your configuration to this link)
* Prepare the host: testsuite_host_conf.sh
* Deploy VM: testsuite_deploy_vm.sh
* Init the cluster: testsuite_init_cluster.sh
* Your cluster is now able to run some scenarios

## havm.conf configuration file
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
* install virtualization tools and restart libvirtd
* generate an ssh root key, and prepare a config to connect to nodes
* add nodes in /etc/hosts
* create a Virtual Network: DHCP with host/mac/name/ip for nodes
* create an SHARED pool
* prepapre an image (raw) which contains autoyast file

### testsuite_deploy_vm.sh
This script will install all nodes with needed data
* clean-up all previous data: VM definition, VM images
* create an slepool to store VM images
* install all VM (using a screen)
* display information how to copy host root key to nodes (VM)

### testsuite_init_cluster.sh
Finish the nodes installation and run some tests.

*NOTE* Use the [force] option to bypass the cluster check.


## AutoYast files

Files used for auto-installation of nodes. Files are copied into
a image file (vm_xml.raw) and used as a disk image under VM.

### vm.xml
This file is the autoyast profile with Graphical interface installation.

### vm_mini.xml
This file is the autoyast profile (simple without GUI/X).

## functions
Contains needed functions for all scripts.


### scenarios directory
This directory contains some scenarios you can run on you cluster to test it.
