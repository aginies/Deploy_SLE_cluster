#!/bin/sh
#########################################################
#
#
#########################################################
## MPI TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other


prepare_mpi() {
    echo "############ START prepare_mpi"
#git clone https://github.com/wesleykendall/mpitutorial
#zypper in nfs-utils
#zypper in make
#module load gnu
#module load openmpi
#mpicc -o mpi_hello_world mpi_hello_world.c
}

##########################
##########################
### MAIN
##########################
##########################

echo "############ MPI TEST SCENARIO #############"
echo
echo " One node will NFS export /export  (${NODENAME}1)"
echo
echo " press [ENTER] twice OR Ctrl+C to abort"
read
read


