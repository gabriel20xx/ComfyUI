#!/bin/bash

# Pre-requisites (run first):
# - 00-nvidiaDev.sh

# https://github.com/thu-ml/SageAttention
sageattention_version="v2.2.0"

set -e

error_exit() {
  echo -n "!! ERROR: "
  echo $*
  echo "!! Exiting script (ID: $$)"
  exit 1
}

source /comfy/mnt/venv/bin/activate || error_exit "Failed to activate virtualenv"

# We need both uv and the cache directory to enable build with uv
use_uv=true
uv="/comfy/mnt/venv/bin/uv"
uv_cache="/comfy/mnt/uv_cache"
if [ ! -x "$uv" ] || [ ! -d "$uv_cache" ]; then use_uv=false; fi

echo "Checking if nvcc is available"
if ! command -v nvcc &> /dev/null; then
    error_exit " !! nvcc not found, canceling run"
fi

if pip3 show setuptools &>/dev/null; then
  echo " ++ setuptools installed"
else
  error_exit " !! setuptools not installed, canceling run"
fi
if pip3 show ninja &>/dev/null; then
  echo " ++ ninja installed"
else
  error_exit " !! ninja not installed, canceling run"
fi

# Decide on build location
cd /comfy/mnt
bb="venv/.build_base.txt"
if [ ! -f $bb ]; then error_exit "${bb} not found"; fi
BUILD_BASE=$(cat $bb)

if [ ! -d src ]; then mkdir src; fi
cd src

mkdir -p ${BUILD_BASE}
if [ ! -d ${BUILD_BASE} ]; then error_exit "${BUILD_BASE} not found"; fi
cd ${BUILD_BASE}

if pip3 show torch &>/dev/null; then
  torch_version=$(pip3 show torch | grep Version | awk '{print $2}' | cut -d'.' -f1-2)
else
  error_exit "torch not installed, canceling run"
fi

if [ -z "$torch_version" ]; then error_exit "error getting torch version, canceling run"; fi
td="Torch_${torch_version}"
if [ ! -d $td ]; then mkdir $td; fi
cd $td

dd="/comfy/mnt/src/${BUILD_BASE}/$td/SageAttention-${sageattention_version}"
if [ -d $dd ]; then
  echo "SageAttention source already present, you must delete it at $dd to force reinstallation"
  exit 0
fi

echo "Compiling SageAttention"
tdd="$dd-`date +%Y%m%d%H%M%S`"

## Clone SageAttention
git clone \
  --branch $sageattention_version \
  --recurse-submodules https://github.com/thu-ml/SageAttention.git \
  $tdd

echo "PIP3_CMD: \"${PIP3_CMD}\""
## Compile SageAttention
# Heavy compilation parallelization: lower the number manually if needed
cd $tdd
numproc=$(nproc --all)
echo " - numproc: $numproc"
ext_parallel=$(( numproc / 2 ))
if [ "$ext_parallel" -lt 1 ]; then ext_parallel=1; fi
echo " - ext_parallel: $ext_parallel"
num_threads=$(( numproc / 2 ))
if [ "$num_threads" -lt 1 ]; then num_threads=1; fi
echo " - num_threads: $num_threads"

if [ "A$use_uv" == "Atrue" ]; then
  echo "== Using uv"
  echo " - uv: $uv"
  echo " - uv_cache: $uv_cache"
else
  echo "== Using pip"
fi

CMD="EXT_PARALLEL=$ext_parallel NVCC_APPEND_FLAGS=\"--threads $num_threads\" MAX_JOBS=$numproc ${PIP3_CMD} ${PIP3_XTRA} . --no-build-isolation"
echo "CMD: \"${CMD}\""
echo $CMD > $tdd/build.cmd; chmod +x $tdd/build.cmd
script -a -e -c $tdd/build.cmd $tdd/build.log || error_exit "Failed to build SageAttention"
cd ..

mv $tdd $dd
echo "++ SageAttention built successfully"
exit 0
