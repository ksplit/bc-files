#!/bin/bash

LLVM_OPT="opt-10"
LLVM_LINK="llvm-link-10"

DRIVER=$1
BASE_DIR="/opt/ksplit/"
PDG="${BASE_DIR}/pdg/build/libpdg.so"
LIBLCD_FUNCS="${BASE_DIR}/bc-files/liblcd_funcs.txt"

DRIVER_BC=${DRIVER}.ko.bc
KERNEL_BC=${DRIVER}_kernel.bc
MERGED_BC=${DRIVER}.bc

NESCHECKLIB_BC="${BASE_DIR}/bc-files/neschecklib.bc"
MERGED_NESCHECK_BC=${DRIVER}_nescheck.bc

if [[ $# != 1 ]]; then
  echo "Not enough arguments"
  echo "run_nescheck.sh <DRIVER_NAME>"
  exit;
fi

merge_bc_files() {
  echo "llvm-link -o $1 $2 $3"
  ${LLVM_LINK} -only-needed -o $1 $2 $3 &> /dev/null
}

compute_boundary_info_pass1() {
  if [ ! -s ${MERGED_BC} ]; then
    echo -e "\e[32m Merging BC files \e[0m"
    merge_bc_files ${MERGED_BC} ${DRIVER_BC} ${KERNEL_BC}
  else
    echo -e "\e[32m [Note]: found merged bc file \e[0m"
  fi

  echo -e "\e[32m Output boundary info ${DRIVER_BC} \e[0m"
  ${LLVM_OPT} -load ${PDG} -libfile ${LIBLCD_FUNCS} -output-boundary-info < ${DRIVER_BC} &> /dev/null
}

compute_shared_data() {
  echo -e "\e[32m Computing shared data on ${MERGED_BC} \e[0m"

  if [ ! -s shared_struct_types ]; then
    echo -e "\e[33m [Warning]: generating shared struct types \e[0m"
    ${LLVM_OPT} -load ${PDG} -shared-data < ${MERGED_BC} &> /dev/null
  else
    echo -e "\e[32m [Note]: found shared struct types \e[0m"
  fi
}

compute_boundary_info_pass2() {
  echo -e "\e[32m Output boundary info ${DRIVER_BC} \e[0m"
  # output boundary
  ${LLVM_OPT} -load ${PDG} -libfile ${LIBLCD_FUNCS} -output-boundary-info < ${DRIVER_BC} &> /dev/null
}

# run nescheck analysis
run_nescheck() {
  if [ ! -f "${MERGED_NESCHECK_BC}" ]; then
    echo -e "\e[33m [Warning]: generating neschecklib bc file \e[0m"
    merge_bc_files ${MERGED_NESCHECK_BC} ${MERGED_BC} ${NESCHECKLIB_BC}
  else
    echo -e "\e[32m [Note]: found neschecklib bc file \e[0m"
  fi

  echo -e "\e[32m Running nescheck on ${MERGED_NESCHECK_BC} \e[0m"
  ${LLVM_OPT} -load ${PDG} -nescheck -raw-stats=true -analysis-stats=true -time-passes < ${MERGED_NESCHECK_BC} > nescheck_stats 2> /dev/null
}

compute_boundary_info_pass1
compute_shared_data
compute_boundary_info_pass2
run_nescheck
