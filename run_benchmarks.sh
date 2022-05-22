#!/bin/bash

BASE_DIR="/opt/ksplit"
BCFILES="${BASE_DIR}/bc-files"

STATS_DIR="${BCFILES}/benchmark_stats"
TABLE1_DRIVERS="${BCFILES}/table1_drivers_list"
TABLE2_DRIVERS="${BCFILES}/table2_drivers_list"
TABLE2_SUBSYSTEMS=${BCFILES}/subsystem_list

TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')

run_analysis()  {
  DRIVER_LIST=$1

  declare -a PIDS
  idx=0

  while IFS= read -r line
  do
    DRIVER_BC_DIR="${line}"
    pushd ${DRIVER_BC_DIR} > /dev/null
    echo ${PWD}
    bench_name="${PWD##*/}"
    echo "Processing ${bench_name} driver"
    ${BCFILES}/run_nescheck.sh ${bench_name} &
    PID=$!
    #echo "Running the analysis in the background (pid ${PID})"
    PIDS[${idx}]=${PID}
    idx=$((${idx}+1))

    # Wait for the analysis to start consuming memory
    sleep 25

    FREE_MEM=$(grep MemFree /proc/meminfo | awk '{print $2}')
    PERCENT_FREE=$(echo "${FREE_MEM} * 100 / ${TOTAL_MEM}" | bc)

    # Wait for the existing ones to finish to avoid OOM crashes
    while [[ ${PERCENT_FREE} < 40 ]]; do
      sleep 5
      FREE_MEM=$(grep MemFree /proc/meminfo | awk '{print $2}')
      PERCENT_FREE=$(echo "${FREE_MEM} * 100 / ${TOTAL_MEM}" | bc)
    done
    popd > /dev/null
  done < "${DRIVER_LIST}"

  for p in ${PIDS[*]}; do
    echo "Waiting for pid ${p}"
    wait $p
    echo "Process ${p} finished"
  done
}

collect_output() {
  OUTPUT_FILE=$1
  DRIVER_LIST=$2
  while IFS= read -r line
  do
    DRIVER_BC_DIR=${line}
    pushd ${DRIVER_BC_DIR} > /dev/null
    if [ -s ${OUTPUT_FILE} ]; then
      bench_name="${PWD##*/}"
      echo "Analysis complete for ${DRIVER_BC_DIR}"
      echo "Copying ${bench_name} stats to ${STATS_DIR}"
      cp -v ${OUTPUT_FILE} ${STATS_DIR}/${bench_name}.csv
    fi
    popd > /dev/null
  done < ${DRIVER_LIST}
}

merge_to_csv() {

  TABLE1_PY_SCRIPT=${STATS_DIR}/merge_to_csv.py

  pushd ${STATS_DIR} > /dev/null
  if [[ -s ${TABLE1_PY_SCRIPT} ]]; then
    $(which python3) ${TABLE1_PY_SCRIPT}
    echo "Merged csv is at ${STATS_DIR}/merged_stats.csv"
  else
    echo "Merge script ${TABLE1_PY_SCRIPT} not found"
  fi
  popd > /dev/null
}

run_table1() {
  run_analysis ${TABLE1_DRIVERS}
  collect_output "table1" ${TABLE1_DRIVERS}
  merge_to_csv
}

get_driver_list() {
  SUBSYS_LIST=$1
  truncate -s 0 ${TABLE2_DRIVERS}

  while IFS= read -r line
  do
    pushd "${BCFILES}/${line}" > /dev/null
    for d in $(ls -d */); do
      ABS_PATH=$(readlink -f ${d})
      echo ${ABS_PATH} >> ${TABLE2_DRIVERS}
    done
    popd > /dev/null
  done < "${SUBSYS_LIST}"
}

collect_table2_output() {
  OUTPUT_FILE=$1
  mkdir -p ${STATS_DIR}/table2

  while IFS= read -r line
  do
    SUBSYS_DIR=${line}
    pushd ${SUBSYS_DIR} > /dev/null
    SUBSYS_NAME="${PWD##*/}"
    echo "Summarizing table2_stats for ${line}"
    $(which python3) ../summarize_module_stats.py
    if [[ -s ${OUTPUT_FILE} ]]; then
      echo "Analysis complete for ${SUBSYS_DIR}"
      echo "Copying ${SUBSYS_NAME} stats to ${STATS_DIR}"
      cp -v ${OUTPUT_FILE} ${STATS_DIR}/table2/${SUBSYS_NAME}.csv
    fi
    popd > /dev/null
  done < ${TABLE2_SUBSYSTEMS}
}

merge_to_csv_table2() {
  TABLE2_PY_SCRIPT=${STATS_DIR}/merge_to_csv_table2.py

  pushd ${STATS_DIR}/table2 > /dev/null
  if [[ -s ${TABLE2_PY_SCRIPT} ]]; then
    $(which python3) ${TABLE2_PY_SCRIPT}
    echo "Merged csv is at ${STATS_DIR}/table2/merged_stats_table2.csv"
  else
    echo "Merge script ${TABLE2_PY_SCRIPT} not found"
  fi
  popd > /dev/null
}

run_table2() {
  get_driver_list ${TABLE2_SUBSYSTEMS}
  run_analysis ${TABLE2_DRIVERS}
  collect_table2_output "table2_stats"
  merge_to_csv_table2
}

EXPERIMENT=$1

case ${EXPERIMENT} in
  "table1")
    echo "Running table1 benchmarks"
    run_table1
    ;;
  "table2")
    echo "Running table2 benchmarks"
    run_table2
    ;;
  *)
    echo "Missing/incorrect argument"
    echo "run_benchmarks.sh table1|table2"
    ;;
esac
