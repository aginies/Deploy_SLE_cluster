#!/bin/sh
#########################################################
#
#
#########################################################
## BUILD ENV
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

build_env() {
    echo $I "############ START build_env" $O
    echo $I "-Install all packages on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper addrepo http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/GA/standard/ ext"
    exec_on_node ${NODENAME}1 "zypper ref ext"
    exec_on_node ${NODENAME}1 "zypper in -y rpmbuild osc"
    exec_on_node ${NODENAME}1 "zypper removerepo ext"
}

get_packages() {
    echo $I "############ START run_check" $O
    exec_on_node test@${NODENAME}1 "osc co home:aginies dolly_plus"
    exec_on_node test@${NODENAME}1 "osc co home:aginies dolly"
    exec_on_node test@${NODENAME}1 "osc co home:aginies Taktuk"
}

##########################
##########################
### MAIN
##########################
##########################

echo $I "############ BUILD ENV #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    env)
	build_env
	;;
    get)
	get_packages
	;;
    all)
	build_env
	;;
    *)
	echo "
usage of $0 {env|get|all}

 env 
	install all package on node1

 get
	get all packages SPM from repo

"
	;;
esac
