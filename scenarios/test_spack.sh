#!/bin/sh
#########################################################
#
#
#########################################################
## SPACK TEST
#########################################################
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


install_spack() {
    echo $I "############ START install_spack" $O
    echo $I "-Install spack bash-completion on ${NODENAME}1" $O
    echo "- Node ${NODENAME}1:"
    exec_on_node ${NODENAME}1 "zypper in -y spack bash-completion"
}


spack_basic() {
    echo $I "############ START spack_basic" $O
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack info netcdf-cxx4"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack versions mpich"
}

spack_install_package() {
    echo $I "############ START spack_install_package" $O
    echo "- Node ${NODENAME}1:"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack install mpich@3.3.2 -romio -libxml2 -hydra -fortran"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack install gcc@10.2.0"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && module load gcc-10.2.0"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && gcc --version"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack compiler find"
}

spack_find() {
    echo $I "############ START spack_find" $O
    echo "- Node ${NODENAME}1:"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack find"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack find -l"
    exec_on_node ${NODENAME}1 ". /usr/share/spack/setup-env.sh && spack find --paths"
}

##########################
##########################
### MAIN
##########################
##########################

echo $I "############ SPACK TEST SCENARIO #############"
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read

case $1 in
    install)
	install_spack
	;;
    basic)
	spack_basic
	;;
    package)
	spack_install_package
	;;
    find)
	spack_find
	;;
    all)
	echo "too complex ... do manually"
	;;
    *)
	echo "usage of $0 

 install
	install spack on ${NODENAME}1

 basic
 	test some spack basic command

 package
        install package using spack, will take some time as this 
	is a build from scratch

 find
 	test the spack find feature

"
	;;
esac
