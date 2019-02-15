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
    echo $I "############ START prepare_mpi" $O
    #git clone https://github.com/wesleykendall/mpitutorial
    scp_on_node mpi_hello_world.c "mpitest@${NODENAME}1:/export"
    exec_on_node ${NODENAME}1 "zypper in -y make"
    exec_on_node mpitest@${NODENAME}1 "cat > /export/build_prepare_mpi.sh <<EOF
#!/bin/sh
module load gnu
module load openmpi
mpicc -o mpi_hello_world mpi_hello_world.c
EOF"
    exec_on_node mpitest@${NODENAME}1 "cd /export && sh /export/build_prepare_mpi.sh"
}

nfs_server() {
    echo $I "############ START nfs_server" $O
    exec_on_node ${NODENAME}1 "zypper in -y nfs-utils"
    exec_on_node ${NODENAME}1 "cp -vf /etc/exports /etc/exports.bck"
    exec_on_node ${NODENAME}1 "mkdir /export" IGNORE=1
    exec_on_node ${NODENAME}1 "echo '/export	*(rw,root_squash,sync,no_subtree_check)' > /etc/exports"
    exec_on_node ${NODENAME}1 "systemctl enable nfs-server.service"
    exec_on_node ${NODENAME}1 "systemctl restart nfs-server.service"
    exec_on_node ${NODENAME}1 "exportfs"
}

run_mpi() {
    echo $I "############ START run_mpi" $O
    exec_on_node mpitest@${NODENAME}1 "cat > /export/run_mpi_test.sh <<EOF
#!/usr/bin/env bash
#Job name
#S -J plop
# Asking for one node
#S -N 8
module load gnu
module load openmpi
mpirun -n 8 /export/mpi_hello_world
EOF"
    exec_on_node mpitest@${NODENAME}1 "sh /export/run_mpi_test.sh"
    exec_on_node mpitest@${NODENAME}1 "module load gnu && module load openmpi && mpirun --hostfile /etc/nodes -n 8 /export/mpi_hello_world"
    exec_on_node mpitest@${NODENAME}1 "sbatch -n 8 run_mpi_test.sh"

    cat >slurm_exec.sh <<EOF
#!/usr/bin/env bash
#Job name
#SBATCH -J TEST_Slurm
# Asking for one node
#SBATCH -N 1
# Output results message
#SBATCH -o slurm-%j.out
# Output error message
#SBATCH -e slurm-%j.err
module purge
echo '=====my job informations ==== '
echo 'Node List: ' $SLURM_NODELIST
echo 'my jobID: ' $SLURM_JOB_ID
echo 'Partition: ' $SLURM_JOB_PARTITION
echo 'submit directory:' $SLURM_SUBMIT_DIR
echo 'submit host:' $SLURM_SUBMIT_HOST
echo 'In the directory: \`pwd\`'
echo 'As the user: \`whoami\`'
EOF
    scp_on_node slurm_exec.sh "mpitest@${NODENAME}1:/export"
    rm -f slurm_exec.sh
}

user_mpi() {
    echo $I "############ START user_mpi" $O
    for i in `seq 1 $NBNODE`
    do
	exec_on_node ${NODENAME}${i} "useradd -d /export -g users -G slurm -M -p "a" -u 666 mpitest" IGNORE=1
    done
    exec_on_node ${NODENAME}1 "mkdir -p /export/.ssh"
    scp_on_node ~/.ssh/${IDRSA}.pub "${NODENAME}1:/export/.ssh/authorized_keys"
    exec_on_node ${NODENAME}1 "chown mpitest.users -R /export/"
    exec_on_node mpitest@${NODENAME}1 "ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''"
    exec_on_node mpitest@${NODENAME}1 "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
    exec_on_node mpitest@${NODENAME}1 "cat > ~/.ssh/config <<EOF
Host *
    StrictHostKeyChecking no
EOF"
}

nfs_client() {
    echo $I "############ START nfs_client" $O
    # only starting from NODE2 as node1 export the NFS dir
    for i in `seq 2 $NBNODE`
    do 
#	exec_on_node ${NODENAME}${i} "zypper in -y nfs-utils"
	exec_on_node ${NODENAME}${i} "systemctl enable nfs"
	exec_on_node ${NODENAME}${i} "systemctl start nfs"
	exec_on_node ${NODENAME}${i} "mkdir /export" IGNORE=1
	exec_on_node ${NODENAME}${i} "echo '${NODENAME}1:/export	/export	nfs	noauto,rw,bg,exec,suid,dev,soft,nolock,async 0 0' >> /etc/fstab"
	exec_on_node ${NODENAME}${i} "mount ${NODENAME}1:/export /export"
    done
}

back_to_start() {
    echo $I "############ START back_to_start" $O
    exec_on_node  ${NODENAME}1 "cp -vf /etc/exports.bck /etc/exports"
    exec_on_node  ${NODENAME}1 "systemctl restart nfs-server.service"
    for i in `seq 1 $NBNODE`
    do
	exec_on_node ${NODENAME}${i} "umount /export"
	exec_on_node ${NODENAME}${i} "rm -rf /export"
	exec_on_node ${NODENAME}${i} "userdel mpitest"
    done
}

##########################
##########################
### MAIN
##########################
##########################

echo $I "############ MPI TEST SCENARIO #############"
echo
echo " One node will NFS export /export  (${NODENAME}1)"
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    mpi)
	prepare_mpi
	;;
    nserver)
	nfs_server
	;;
    nclient)
	nfs_client
	;;
    usermpi)
	user_mpi
	;;
    runmpi)
	run_mpi
	;;
    back)
	back_to_start
	;;
    all)
	nfs_server
	nfs_client
	mpi
	runmpi
	;;
    *)
	echo "
usage of $0 {mpi|nserver|nclient|runmpi|usermpi|back|all}

 nserver
	prepare an /export dir for testing

 nclient
	mount /export on all nodes	

 usermpi
	create an mpitest usr on all nodes (will used /export)
	deal with ssh key

 mpi
	compile a basic mpi test with mpicc
 
 runmpi
	run a basic mpitest on all nodes
 
 restore
	go back to initial state
"
	;;
esac
