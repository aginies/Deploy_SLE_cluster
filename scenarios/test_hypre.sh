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
    exec_on_node ${NODENAME}1 "zypper in -y superlu_5_2_1-gnu-hpc-devel hypre-gnu-openmpi2-hpc-devel blas-devel"
}

BSCRIPTNAME=build_hypre.sh
build_hypre() {
    echo $I "############ START build_hypre" $O
    cat > ${BSCRIPTNAME} <<EOF
#!/bin/sh
EXAMPLED=hypre_2_15_1-gnu-openmpi2-hpc-examples
rm -rf ~/\${EXAMPLED}
cp -a /usr/share/doc/packages/\${EXAMPLED} ~/\${EXAMPLED}
module available
module load gnu
module load openblas
module load superlu
module load hypre
cd ~/\${EXAMPLED}/examples
#mpicc  -g -Wall -I/usr/lib/hpc/gnu7/openmpi2/hypre/2.15.1/include -DHAVE_CONFIG_H -DHYPRE_TIMING -c ex1.c
#mpicc -o ex1 ex1.o -L/usr/lib/hpc/gnu7/superlu/5.2.1/lib64/ -L/usr/lib/hpc/gnu7/openmpi2/hypre/2.15.1/lib64 -lHYPRE -lm -lstdc++ -lblas -llapack -lsuperlu
make -j 4
EOF
    scp_on_node ${BSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${BSCRIPTNAME}"
    rm ${BSCRIPTNAME}
}

RSCRIPTNAME=run_hypre.sh
run_hypre() {
    echo $I "############ START run_hypre" $O
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
EXAMPLED=hypre_2_15_1-gnu-openmpi2-hpc-examples
cd  ~/\${EXAMPLED}/examples
module load gnu
module load openblas
module load superlu
module load hypre
mpirun -np 4 ex10 -n 120 -solver 2
mpirun -np 4 ex11
mpirun -np 2 ex12 -pfmg
mpirun -np 2 ex12f
mpirun -np 6 ex13 -n 10
mpirun -np 6 ex14 -n 10
mpirun -np 8 ex15big -n 10
mpirun -np 8 ex15 -n 10
mpirun -np 4 ex16 -n 10
mpirun -np 16 ex17 -n 10
mpirun -np 16 ex18 -n 4
mpirun -np 16 ex18comp -n 4
mpirun -np 2 ex1
mpirun -np 2 ex2
mpirun -np 16 ex3 -n 33 -solver 0 -v 1 1
mpirun -np 16 ex4 -n 33 -solver 10 -K 3 -B 0 -C 1 -U0 2 -F 4
mpirun -np 4 ex5big
mpirun -np 4 ex5
mpirun -np 4 ex5f
mpirun -np 2 ex6
mpirun -np 16 ex7 -n 33 -solver 10 -K 3 -B 0 -C 1 -U0 2 -F 4
mpirun -np 2 ex8
mpirun -np 16 ex9 -n 33 -solver 0 -v 1 1
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RSCRIPTNAME}"
    rm ${RSCRIPTNAME}
}

clean_hypre() {
    echo $I "############ START clean_hypre" $O
    exec_on_node test@${NODENAME}1 "rm -f ${BSCRIPTNAME}"
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
    build)
	build_hypre
	;;
    run)
	run_hypre
	;;
    clean)
	clean_hypre
	;;
    all)
	prepare_hypre
	build_hypre
	run_hypre
	clean_hypre
	;;
    *)
	echo "
usage of $0 {hypre|build|run|clean|all}

 hypre 
	install hypre on node1

 build
	build the hypre examples

 run
	run the test 

 clean
	rm script file

"
	;;
esac
