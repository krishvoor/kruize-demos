#!/bin/bash
#
# Copyright (c) 2021, 2022 Red Hat, IBM Corporation and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#########################################################################################
#    This script is to run the benchmark as part of trial in an experiment.             #
#    All the tunables configuration from optuna are inputs to benchmark.                #
#    This script has only techempower as the benchmark.                                 #
#                                                                                       #
#########################################################################################

##TO DO: Check if minikube is running and has prometheus installed to capture the data

HPO_CONFIG=$1
SEARCHSPACE_JSON=$2
TRIAL=$3
#DURATION=$4
PY_CMD="python3"
LOGFILE="${PWD}/hpo.log"
BENCHMARK_NAME="hyper-scale"
BENCHMARK_LOGFILE="${PWD}/benchmark.log"

cpu_request=$(${PY_CMD} -c "import hpo_helpers.utils; hpo_helpers.utils.get_tunablevalue(\"hpo_config.json\", \"cpuRequest\")")
memory_request=$(${PY_CMD} -c "import hpo_helpers.utils; hpo_helpers.utils.get_tunablevalue(\"hpo_config.json\", \"memoryRequest\")")

if [[ ${BENCHMARK_NAME} == "hyper-scale" ]]; then

	## HEADER of techempower benchmark output.
	# headerlist = {'CPU_USAGE','MEM_USAGE','DEPLOYMENT_NAME','NAMESPACE','IMAGE_NAME','CONTAINER_NAME'}

	OBJFUNC_VARIABLES="KUBE_APISERVER_RESPONSE"
	CLUSTER_TYPE="openshift"
	BENCHMARK_SERVER="localhost"
	RESULTS_DIR="results"
	ITERATIONS=1
	NAMESPACE="default"

	./benchmarks/hyper-scale/scripts/perf/run_me.sh -e ${RESULTS_DIR} -n ${NAMESPACE} --cpureq=${cpu_request} --memreq=${memory_request}M >& ${BENCHMARK_LOGFILE}

	RES_DIR=`ls -td -- ./benchmarks/techempower/results/*/ | head -n1 `
	if [[ -f "${RES_DIR}/output.csv" ]]; then
		## Copy the output.csv into current directory
		cp -r ${RES_DIR}/output.csv .
		cat ${RES_DIR}/../../setup.log >> ${BENCHMARK_LOGFILE}
		## Format csv file
		sed -i 's/[[:blank:]]//g' output.csv
		## Calculate objective function result value
		objfunc_result=`${PY_CMD} -c "import hpo_helpers.getobjfuncresult; hpo_helpers.getobjfuncresult.calcobj(\"${SEARCHSPACE_JSON}\", \"output.csv\", \"${OBJFUNC_VARIABLES}\")"`
	
		if [[ ${objfunc_result} != "-1" ]]; then
			benchmark_status="success"
		else
			benchmark_status="failure"
			echo "Error calculating the objective function result value" >> ${LOGFILE}
		fi
	else
		benchmark_status="failure"
	fi

	if [[ ${benchmark_status} == "failure" ]];then
		objfunc_result=0
	fi
	### Add the HPO config and output data from benchmark of all trials into single csv
        ${PY_CMD} -c "import hpo_helpers.utils; hpo_helpers.utils.hpoconfig2csv(\"hpo_config.json\",\"output.csv\",\"experiment-output.csv\",\"${TRIAL}\")"

	## Remove the benchmark output file which is copied.
	rm -rf output.csv

fi


echo "Objfunc_result=${objfunc_result}"
echo "Benchmark_status=${benchmark_status}"
