#!/bin/bash

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
echo "Index URL: $url"

if [ "A$use_uv" == "Atrue" ]; then
  echo "== Using uv"
  echo " - uv: $uv"
  echo " - uv_cache: $uv_cache"
  uv pip install xformers $url || error_exit "Failed to uv install xformers"
else
  echo "== Using pip"
  pip3 install xformers $url || error_exit "Failed to install xformers"
fi

exit 0
