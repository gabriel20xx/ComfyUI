#!/bin/bash

# Pre-requisites (run first):
# - 00-nvidiaDev.sh

# https://github.com/nunchaku-tech/nunchaku
nunchaku_version="v1.2.1"

# detects the compute capability of the GPUs present on the machine and compiles only for those SMs
export NUNCHAKU_INSTALL_MODE=FAST

# --- CONFIGURATION ---
FORCE_REINSTALL="${FORCE_REINSTALL:-false}"
# ---------------------

# --- COLOR CODES (for console)---
LOG_ERR=$(printf '\033[0;41m') # White on RED BG
# LOG_ERR=$(printf '\033[0;91m') # Red on Black BG
# LOG_ERR=$(printf '\033[0m') # No Color

LOG_WARN=$(printf '\033[0;33m') # Yellow
# LOG_WARN=$(printf '\033[0m') # No Color 

LOG_OK=$(printf '\033[0;32m') # GREEN
# LOG_OK=$(printf '\033[0m') # No Color 

# LOG_INFO=$(printf '\033[0;32m') # Green 
LOG_INFO=$(printf '\033[0m') # No Color

NC=$(printf '\033[0m') # No Color
# --------------------------------

set -e

error_exit() {
 echo -n -e "${LOG_ERR}!! ERROR: ${NC}"
  echo $*
  echo "!! Exiting nunchaku script (ID: $$)"
  exit 1
}

source /comfy/mnt/venv/bin/activate || error_exit "Failed to activate virtualenv"

# --- CHECK EXISTING INSTALLATION ---
if [ "$FORCE_REINSTALL" = "false" ]; then
    if pip show nunchaku > /dev/null 2>&1; then
        echo "${LOG_INFO}INFO:${NC} Nunchaku is already installed."
        echo "     (Set FORCE_REINSTALL=true in script to force rebuild/reinstall)"
        exit 0
    fi
else
    echo " !! FORCE_REINSTALL is true. Proceeding..."
fi
# -----------------------------------

echo "** Installing nunchaku**"

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

dd="/comfy/mnt/src/${BUILD_BASE}/$td/nunchaku-${nunchaku_version}"
if [ -d $dd ]; then
  echo "${LOG_WARN}WARNING:${NC} Nunchaku source already present, you must delete it at $dd to force reinstallation"
  exit 0
fi

echo "Compiling Nunchaku"
tdd="$dd-`date +%Y%m%d%H%M%S`"

## Clone Nunchaku
git clone \
  --branch $nunchaku_version \
  --recurse-submodules \
  https://github.com/nunchaku-tech/nunchaku.git \
  $tdd

echo "PIP3_CMD: \"${PIP3_CMD}\""
# Compile Nunchaku
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

# Install Cython (needed by insightface build)
echo "== Installing Cython (build dependency for insightface)"
${PIP3_CMD} Cython || error_exit "Failed to install Cython"

CMD="EXT_PARALLEL=$ext_parallel NVCC_APPEND_FLAGS=\"--threads $num_threads\" MAX_JOBS=$numproc ${PIP3_CMD} -e \".[dev,docs]\" --no-build-isolation"
echo "CMD: \"${CMD}\""
echo $CMD > $tdd/build.cmd; chmod +x $tdd/build.cmd
script -a -e -c $tdd/build.cmd $tdd/build.log || error_exit "Failed to build Nunchaku"

mv $tdd $dd
echo "${LOG_OK}SUCCESS:${NC} Nunchaku built successfully"
exit 0
