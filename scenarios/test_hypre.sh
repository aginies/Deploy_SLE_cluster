#!/bin/sh
#########################################################
#
#
#########################################################
## HYPRE TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

prepare_hypre() {
    echo $I "############ START prepare_hypre" $O
    echo $I "-Install hypre on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y hypre-gnu-hpc* superlu_5_2_1-gnu-hpc-devel hypre-gnu-openmpi2-hpc-devel blas-devel"
}

RSCRIPTNAME=run_hypre.sh
run_hypre() {
    echo $I "############ START run_hypre" $O
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
EXAMPLED=hypre-examples
cp -a /usr/share/doc/packages/${EXAMPLED} ~/${EXAMPLED}
cd ~/${EXAMPLED}
module available
module load gnu
module load blas
module load superlu
module load hypre
#mpicc  -g -Wall -I/usr/lib/hpc/gnu7/openmpi2/hypre/2.15.1/include -DHAVE_CONFIG_H -DHYPRE_TIMING -c ex1.c
#mpicc -o ex1 ex1.o -L/usr/lib/hpc/gnu7/superlu/5.2.1/lib64/ -L/usr/lib/hpc/gnu7/openmpi2/hypre/2.15.1/lib64 -lHYPRE -lm -lstdc++ -lblas -llapack -lsuperlu
make
#mpirun -np 6 ex13 -n 10
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RSCRIPTNAME}"
    rm ${RSCRIPTNAME}
}

clean_hypre() {
    echo $I "############ START clean_hypre" $O
    exec_on_node test@${NODENAME}1 "rm -f ${RSCRIPTNAME}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ HYPRE TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    hypre)
	prepare_hypre
	;;
    run)
	run_hypre
	;;
    clean)
	clean_hypre
	;;
    all)
	prepare_hypre
	run_hypre
	clean_hypre
	;;
    *)
	echo "
usage of $0 {hypre|run|clean|all}

 hypre 
	install hypre on node1

 run
	run the test 

 clean
	rm script file

"
	;;
esac
