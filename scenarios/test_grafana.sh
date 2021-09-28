#!/bin/sh
#########################################################
#
#
#########################################################
## GRAFANA PROMETHEUS TEST
#########################################################

if [ -f ../functions ] ; then
    . ../functions
else
    echo "! functions file needed! ; Exiting"
    exit 1
fi
check_load_config_file other


install_grafana_prometheus() {
    echo $I "############ START install_grafana_prometheus" $O
    exec_on_node ${NODENAME}1 "zypper in -y golang-github-prometheus-prometheus grafana"
}

start_prometheus() {
    echo $I "############ START start_prometheus" $O
    exec_on_node ${NODENAME}1 "systemctl enable prometheus"
    exec_on_node ${NODENAME}1 "systemctl start prometheus"
    echo ""
    echo " - Prometheus config available at http://${NODENAME}1:9090/config"
    exec_on_node ${NODENAME}1 "wget localhost:9090/config --output-document=-"
}


restart_prometheus() {
    echo $I "############ START restart_prometheus" $O
    exec_on_node ${NODENAME}1 "systemctl start prometheus"
}

start_grafana() {
    echo $I "############ START start_grafana" $O
    exec_on_node ${NODENAME}1 "systemctl enable grafana-server"
    exec_on_node ${NODENAME}1 "systemctl start grafana-server"
    echo ""
    echo " - Grafana web server available at http://${NODENAME}1:3000"
    echo " default auth: admin/admin"
}

monitor_slurm() {
    echo $I "############ START monitor_slurm" $O
    for i in `seq 1 $NBNODE`
    do
	exec_on_node ${NODENAME}${i} "zypper in golang-github-vpenso-prometheus_slurm_exporter"
	exec_on_node ${NODENAME}${i} "systemctl enable prometheus-slurm_exporter"
	exec_on_node ${NODENAME}${i} "systemctl start prometheus-slurm_exporter"
    done
    exec_on_node ${NODENAME}1 "wget exec_on_node ${NODENAME}1:8080/metrics --output-document=-"
    echo "http://${NODENAME}1:8080/metrics"
    echo "dashboard ID 4323"
}

monitor_workload() {
    echo $I "############ START monitor_workload" $O
    for i in `seq 1 $NBNODE`
    do
	exec_on_node ${NODENAME}${i} "zypper in golang-github-prometheus-node_exporter"
	exec_on_node ${NODENAME}${i} "systemctl enable prometheus-node_exporter"
	exec_on_node ${NODENAME}${i} "systemctl start prometheus-node_exporter"
    done
    exec_on_node ${NODENAME}1 "wget exec_on_node ${NODENAME}1:9100/metrics --output-document=-"
    echo "http://${NODENAME}1:9100/metrics"
    echo "dashboard ID 405"
}

prometheus_config() {
    echo $I "############ START prometheus_config" $O
    #/etc/prometheus/prometheus.yml
    scp_on_node "${NODENAME}1:/etc/prometheus/prometheus.yml" prometheus.yml
    grep slurm-exporter prometheus.yml
    if [ "$?" -ne "0" ]; then
    cat >> prometheus.yml <<EOF
  - job_name: slurm-exporter
    scrape_interval: 30s
    scrape_timeout: 30s
    static_configs:
      - targets: ['${NODENAME}1:8080']

  - job_name: node-exporter
    static_configs:
EOF
    for i in `seq 1 $NBNODE`
    do	    
        echo "      - targets: ['${NODENAME}${i}:9100']" >> prometheus.yml
    done
    scp_on_node prometheus.yml "${NODENAME}1:/etc/prometheus/prometheus.yml" prometheus.yml
    else
	echo "- seems prometheus.yml already contains needed modification"
    fi
    rm -vf prometheus.yml
}

dashboard() {
    echo $I "############ START dashboard" $O
    echo "Log in to the Grafana web server at http://${NODENAME}1:3000
Slurm:
In the Import via grafana.com field, enter the dashboard ID 4323, then click Load
Select a Prometheus data source drop-down box
"
    echo "
Workload:
In the Import via grafana.com field, enter the dashboard ID 405, then click Load.
Select a Prometheus data source drop-down box
"
}

##########################
##########################
### MAIN
##########################
##########################

echo $I "############ GRAFANA PROMETHEUS TEST SCENARIO #############"
echo
echo " One node will be grafana/prometheus server (${NODENAME}1)"
echo $O
#echo " press [ENTER] twice OR Ctrl+C to abort"
#read
#read
echo

case $1 in
    install)
	install_grafana_prometheus
	;;
    sprometheus)
	start_prometheus
	;;
    sgrafana)
	start_grafana
	;;
    rprometheus)
	restart_prometheus
	;;
    config)
	prometheus_config
	;;
    mslurm)
	monitor_slurm
        ;;
    mworkload)
	monitor_workload
	;;
    dashboard)
	dashboard
	;;
    all)
	install_grafana_prometheus
	start_prometheus
	start_grafana
	monitor_slurm
	monitor_workload
	prometheus_config
	restart_prometheus
	dashboard
        ;;
    *)
	echo "
usage of $0

PackageHub repository is mandatory to be able to install needed packages
(testsuite_init_cluster.sh scc)

 install
 	install prometheus and grafana server

 sprometheus
 	start prometheus server and check

 sgrafana
	start grafana server and check

 mslurm
 	install packages and monitor slurm

 mworkload
 	install packages and monitor node workload

 config
 	adjust prometheus configuration with workload and slurm monitoring

 rprometheus
 	restart prometheus server

 dashboard
 	some explanation about dashboarding in grafana

 all
 	try to do all steps in correct order
"
	;;
esac
