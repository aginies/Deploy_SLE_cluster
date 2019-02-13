#!/bin/sh
#########################################################
#
#
#########################################################
## IMB TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

prepare_imb() {
    echo $I "############ START prepare_imb" $O
    echo $I "-Install imb on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y imb-gnu-mpich-hpc imb-gnu-openmpi2-hpc"
}

RSCRIPTNAME=run_imb.sh
run_imb() {
    echo $I "############ START run_imb" $O
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
cd /usr/lib/hpc/gnu7/openmpi2/imb/2019.1/bin/
module available
module load gnu
module load openmpi
echo "--------------- RUN IMB-EXT"
./IMB-EXT 
echo
echo "--------------- RUN IMB-MPI1"
./IMB-MPI1
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RSCRIPTNAME}"
    rm ${RSCRIPTNAME}
}

clean_imb() {
    echo $I "############ START clean_imb" $O
    exec_on_node test@${NODENAME}1 "rm -f ${RSCRIPTNAME}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ IMB TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    imb)
	prepare_imb
	;;
    run)
	run_imb
	;;
    clean)
	clean_imb
	;;
    all)
	prepare_imb
	run_imb
	clean_imb
	;;
    *)
	echo "
usage of $0 {imb|run|clean|all}

 imb
	install IMB on node1

 run
	run the test 

 clean
	rm script file

"
	;;
esac
