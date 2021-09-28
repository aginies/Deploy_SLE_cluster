#!/bin/sh
#########################################################
#
#
#########################################################
## METIS TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

prepare_metis() {
    echo $I "############ START prepare_metis" $O
    echo $I "-Install metis on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y metis-gnu-hpc* metis-examples"
}

RSCRIPTNAME=run_metis.sh
run_metis() {
    echo $I "############ START run_metis" $O
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
GRAPHSD=/usr/share/doc/packages/metis-examples/graphs/
rm -rf \${LDIR}
LDIR=metis-graphs
cp -a \${GRAPHSD} \${LDIR}
module available
module load gnu
module load metis
cd \${METIS_DIR}/bin
./graphchk ~/\${LDIR}/4elt.graph
./graphchk ~/\${LDIR}/mdual.graph
./gpmetis ~/\${LDIR}/mdual.graph 4
./ndmetis ~/\${LDIR}/mdual.graph
./ndmetis ~/\${LDIR}/copter2.graph
./m2gmetis ~/\${LDIR}/metis.mesh ~/\${LDIR}/copter2.graph
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RSCRIPTNAME}"
    rm ${RSCRIPTNAME}
}

clean_metis() {
    echo $I "############ START clean_metis" $O
    exec_on_node test@${NODENAME}1 "rm -f ${RSCRIPTNAME}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ METIS TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    metis)
	prepare_metis
	;;
    run)
	run_metis
	;;
    clean)
	clean_metis
	;;
    all)
	prepare_metis
	run_metis
	clean_metis
	;;
    *)
	echo "
usage of $0 {metis|run|clean|all}

 metis 
	install metis on node1

 run
	run the test 

 clean
	rm script file

"
	;;
esac
