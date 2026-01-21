#!/bin/bash

# Pre-requisites (run first):
# - 00-nvidiaDev.sh

# Install xformers
# 
# https://github.com/facebookresearch/xformers

echo "** Installing xformers**"

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

cd /comfy/mnt
bb="venv/.build_base.txt"
if [ ! -f $bb ]; then error_exit "${bb} not found"; fi
BUILD_BASE=$(cat $bb)
# extract CUDA version from build base
CUDA_VERSION=$(echo $BUILD_BASE | grep -oP 'cuda\d+\.\d+')
if [ -z "$CUDA_VERSION" ]; then error_exit "CUDA version not found in build base"; fi

echo "CUDA version: $CUDA_VERSION"

must_build=false
# check PyTorch version: < 2.10 cam use pip3, otherwise must build
if pip3 show torch &>/dev/null; then
  torch_version=$(pip3 show torch | grep Version | awk '{print $2}' | cut -d'.' -f1-2)
  if [ "A$torch_version" == "A2.10" ]; then must_build=true; fi
fi

echo "PyTorch version: $torch_version"
echo "must_build: \"${must_build}\""

if [ "A$must_build" == "Atrue" ]; then
  echo "PIP3_CMD: \"${PIP3_CMD}\""
  if [ ! -d src ]; then mkdir src; fi
  cd src

  mkdir -p ${BUILD_BASE}
  if [ ! -d ${BUILD_BASE} ]; then error_exit "${BUILD_BASE} not found"; fi
  cd ${BUILD_BASE}

  dd="/comfy/mnt/src/${BUILD_BASE}/xformers-git"
  if [ -d $dd ]; then
    echo "xformers source already present, you must delete $dd to force reinstallation"
    exit 0
  fi
  mkdir -p $dd

  # we are not downloading the source code, we are building from git, as described in the xformers documentation
  if [ "A$use_uv" == "Atrue" ]; then
    echo "== Using uv"
    echo " - uv: $uv"
    echo " - uv_cache: $uv_cache"
  else
    echo "== Using pip"
    echo " - TORCH_INDEX_URL: $TORCH_INDEX_URL"
  fi

  EXT_PARALLEL=$ext_parallel NVCC_APPEND_FLAGS="--threads $num_threads" MAX_JOBS=$numproc ${PIP3_CMD} xformers --no-build-isolation git+https://github.com/facebookresearch/xformers.git@main#egg=xformers || error_exit "Failed to install xformers"
  echo "++ xformers installed successfully"
  exit 0
fi

if [ "A$use_uv" == "Atrue" ]; then
  if [ -z "${UV_TORCH_BACKEND+x}" ]; then error_exit "UV_TORCH_BACKEND is not set"; fi
  echo "== Using uv"
  echo " - uv: $uv"
  echo " - uv_cache: $uv_cache"
  echo " - UV_TORCH_BACKEND: $UV_TORCH_BACKEND"
else
  if [ -z "${TORCH_INDEX_URL+x}" ]; then error_exit "TORCH_INDEX_URL is not set"; fi
  echo "== Using pip"
  echo " - TORCH_INDEX_URL: $TORCH_INDEX_URL"
fi

${PIP3_CMD} xformers || error_exit "Failed to install xformers"

exit 0
