#!/bin/sh
#########################################################
#
#
#########################################################
## SUPERLU TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

SUPERLUVERSION=5.2.1

prepare_superlu() {
    echo $I "############ START prepare_mpi" $O
    echo $I "-Install superlu on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y libsuperlu-gnu-hpc"
}

BSCRIPTNAME=build_superlu.sh
build_examples() {
    echo $I "############ START build_examples" $O
    exec_on_node test@${NODENAME}1 "cp -af /usr/share/doc/packages/superlu_5_?_?-gnu-hpc-examples ~/"
    exec_on_node test@${NODENAME}1 "cat > ${BSCRIPTNAME} <<EOF
#!/bin/sh
cd ~/superlu_5_?_?-gnu-hpc-examples/examples/
module load gnu
module load superlu/${SUPERLUVERSION}
make
"
    exec_on_node test@${NODENAME}1 "bash -x ${BSCRIPTNAME}"
    
}

RSCRIPTNAME=run_superlu.sh
run_superlu() {
    echo $I "############ START run_superlu" $O
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
cd superlu_5_?_?-gnu-hpc-examples/examples/
module load gnu
module load superlu/${SUPERLUVERSION}
for test in \`find .  -executable -type f\`
do
	echo '----------------- $TEST < g20.rua'
        \${test} < g20.rua
	echo '----------------- $TEST < cg20.cua'
        \${test} < cg20.cua
done
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RSCRIPTNAME}"
    rm ${RSCRIPTNAME}
}

clean_superlu() {
    echo $I "############ START clean_superlu" $O
    exec_on_node test@${NODENAME}1 "rm -rf superlu_5_?_?-gnu-hpc-examples"
    exec_on_node test@${NODENAME}1 "rm -f ${BSCRIPTNAME}"
    exec_on_node test@${NODENAME}1 "rm -f ${RSCRIPTNAME}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ SUPERLU TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    superlu)
	prepare_superlu
	;;
    build)
	build_examples
	;;
    run)
	run_superlu
	;;
    clean)
	clean_superlu
	;;
    all)
	prepare_superlu
	build_examples
	run_superlu
	clean_superlu
	;;
    *)
	echo "
usage of $0 {superlu|build|run|clean|all}

 superlu
	install superlu on node1

 build
	build superlu examples

 run
	run all examples

 clean
	rm all examples and files

"
	;;
esac
