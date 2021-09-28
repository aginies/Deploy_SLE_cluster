#!/bin/sh
#########################################################
#
#
#########################################################
# GSL TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

prepare_gsl() {
    echo $I "############ START prepare_gsl" $O
    echo $I "-Install gsl on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y gsl-gnu-hpc* gsl-gnu-hpc-devel gsl-*"
}

RBSCRIPTNAME=build_run_gsl.sh
EXAMPLED=gsl-examples
run_gsl() {
    echo $I "############ START run_gsl" $O
    cat > ${RBSCRIPTNAME} <<EOF
#!/bin/sh
EXAMPLED=gsl-examples
cp -a /usr/share/doc/packages/gsl_2_5-gnu-hpc-examples/examples \${EXAMPLED}
cd \${EXAMPLED}
module available
module load gnu
module load gsl
module load openblas
for code in \`ls *.c\`
do
gcc -lgsl -lopenblas -lm -ldl \${code} -o \${code}.bin
./\${code}.bin
done
EOF
    scp_on_node ${RBSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RBSCRIPTNAME}"
    rm ${RBSCRIPTNAME}
}

clean_gsl() {
    echo $I "############ START clean_gsl" $O
    exec_on_node test@${NODENAME}1 "rm -f ${RBSCRIPTNAME}"
    exec_on_node test@${NODENAME}1 "rm -rf ${EXAMPLED}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ GSL TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    gsl)
	prepare_gsl
	;;
    run)
	run_gsl
	;;
    clean)
	clean_gsl
	;;
    all)
	prepare_gsl
	run_gsl
	clean_gsl
	;;
    *)
	echo "
usage of $0 {gsl|run|clean|all}

 gsl 
	install gsl on node1

 run
	run the test 

 clean
	rm script file

"
	;;
esac
