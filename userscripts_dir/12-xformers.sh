#!/bin/bash

echo "** Installing xformers**"

set -e

error_exit() {
  echo -n "!! ERROR: "
  echo $*
  echo "!! Exiting script (ID: $$)"
  exit 1
}

source /comfy/mnt/venv/bin/activate || error_exit "Failed to activate virtualenv"

cd /comfy/mnt
bb="venv/.build_base.txt"
if [ ! -f $bb ]; then error_exit "${bb} not found"; fi
BUILD_BASE=$(cat $bb)
# ubuntu24_cuda12.9
# extract CUDA version from build base
CUDA_VERSION=$(echo $BUILD_BASE | grep -oP 'cuda\d+\.\d+')
if [ -z "$CUDA_VERSION" ]; then error_exit "CUDA version not found in build base"; fi

echo "CUDA version: $CUDA_VERSION"
url=""
if [ "$CUDA_VERSION" == "cuda12.6" ]; then url="--index-url https://download.pytorch.org/whl/cu126"; fi
if [ "$CUDA_VERSION" == "cuda12.8" ]; then url="--index-url https://download.pytorch.org/whl/cu128"; fi
if [ "$CUDA_VERSION" == "cuda12.9" ]; then url="--index-url https://download.pytorch.org/whl/cu129"; fi

if [ -z "$url" ]; then 
  echo "CUDA version $CUDA_VERSION not supported, skipping xformers installation"
  exit 0
fi

pip3 install -U xformers $url || error_exit "Failed to install xformers"

exit 0
