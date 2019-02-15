#!/bin/sh
#########################################################
#
#
#########################################################
## ENV TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other

prepare_env() {
    echo $I "############ START prepare_env" $O
    echo $I "-Install all packages on node ${NODENAME}1" $O
    exec_on_node ${NODENAME}1 "zypper in -y package_list"
}

export RSCRIPTNAME=check_env_script.sh
prepare_script() {
    echo $I "############ START run_check" $O
    cat > ${RSCRIPTNAME} <<EOF
#!/bin/sh
# first arg should be the lib to check
if [ -z "\$1" ]; then
 echo "- First arg should be the lib to check!"
 echo " Get the list with:
module available
"
exit 1
fi

TOCHECK=\$1
echo " ############# \${TOCHECK} ##################"
# find module to load before being able to load the expecte module
module -t spider \${TOCHECK} | grep gnu | awk -F "gnu/7" '{print \$2}' > /tmp/toload

grep '[^[:blank:]]' < /tmp/toload > /tmp/toload.out
if [ -s /tmp/toload.out ]; then
for toload in \`cat /tmp/toload\`
do
	echo " With preloaded \${toload}"
	module load \${toload}
	module load \${TOCHECK}
	module -t list 
	printenv | grep LMOD_FAMILY_\${TOCHECK^^}
	printenv | grep LMOD_FAMILY_\${TOCHECK^^}_VERSION
	printenv | grep \${TOCHECK^^}_INC
	printenv | grep \${TOCHECK^^}_DIR
	printenv | grep \${TOCHECK^^}_LIB
	printenv | grep \${TOCHECK^^}_BIN
	module unload \${TOCHECK}
	module unload \${toload}
done
else
        module load \${TOCHECK}
	echo " ---- List of loaded modules:"
	module -t list 
	echo " ----"
        printenv | grep LMOD_FAMILY_\${TOCHECK^^}
        printenv | grep LMOD_FAMILY_\${TOCHECK^^}_VERSION
        printenv | grep \${TOCHECK^^}_INC
        printenv | grep \${TOCHECK^^}_DIR
        printenv | grep \${TOCHECK^^}_LIB
        printenv | grep \${TOCHECK^^}_BIN
        module unload \${TOCHECK}
        module unload \${toload}
fi
EOF
    scp_on_node ${RSCRIPTNAME} "test@${NODENAME}1:~/"
    rm ${RSCRIPTNAME}
}

run_some_check() { 
    echo $I "############ START run_some_check" $O
    SCRIPTNAME=check_all_modules.sh
    cat > ${SCRIPTNAME} <<EOF
#!/bin/sh
LIST=/tmp/list_to_check
module load gnu 
module -t -q avail | cut -d '/' -f 1  | uniq | sed '/^\$/d' > \${LIST}

for l in \`cat \${LIST}\` 
do
	sh ./${RSCRIPTNAME} \$l
done
EOF
    scp_on_node ${SCRIPTNAME} "test@${NODENAME}1:~/"
    exec_on_node test@${NODENAME}1 "sh ${SCRIPTNAME}"
    rm ${SCRIPTNAME}

}

clean_env() {
    echo $I "############ START clean_env" $O
    exec_on_node test@${NODENAME}1 "rm -f ${RSCRIPTNAME}"
}


##########################
##########################
### MAIN
##########################
##########################

echo $I "############ METIS ENV SCENARIO #############"
echo
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    env)
	prepare_env
	;;
    prepare)
    prepare_script
	;;
    run)
	run_some_check
	;;
    clean)
	clean_env
	;;
    all)
	prepare_env
	run_some_check
	clean_env
	;;
    *)
	echo "
usage of $0 {env|prepare|run|clean|all}

 env 
	install all package on node1

 prepare
	create the test script

 run
	run the test 

 clean
	rm script file

"
	;;
esac