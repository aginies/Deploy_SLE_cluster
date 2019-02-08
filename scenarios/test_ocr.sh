#!/bin/sh
#########################################################
#
#
#########################################################
## OCR TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

OCRVERSION=1.0.1

prepare_ocr() {
    echo $I "############ START prepare_ocr" $O
    echo $I "-Install ocr on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y zypper in ocr-gnu-*"
}

RSCRIPTNAME=run_ocr.sh
run_ocr() {
    echo $I "############ START run_ocr" $O
    exec_on_node test@${NODENAME}1 "cp -af /usr/share/doc/packages/ocr* ~/"
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
cd ~/ocr-gnu
module load gnu
module load ocr/${OCRVERSION}
./ocrTests -all
"
    exec_on_node test@${NODENAME}1 "bash -x ${BSCRIPTNAME}"
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${RSCRIPTNAME}"
    rm ${RSCRIPTNAME}
}

clean_ocr() {
    echo $I "############ START clean_ocr" $O
    exec_on_node test@${NODENAME}1 "rm -f ${RSCRIPTNAME}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ OCR TEST SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    ocr)
	prepare_ocr
	;;
    run)
	run_ocr
	;;
    clean)
	clean_ocr
	;;
    all)
	prepare_ocr
	run_ocr
	clean_ocr
	;;
    *)
	echo "
usage of $0 {ocr|run|clean|all}

 ocr 
	install ocr on node1

 run
	run the test 

 clean
	rm script file

"
	;;
esac
