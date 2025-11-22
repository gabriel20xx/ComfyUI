#!/bin/bash

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

if [ "A$use_uv" == "Atrue" ]; then
  echo "== Using uv"
  echo " - uv: $uv"
  echo " - uv_cache: $uv_cache"
  uv pip install --upgrade setuptools || error_exit "Failed to uv upgrade setuptools"
  uv pip install ninja cmake wheel pybind11 packaging || error_exit "Failed to uv install build dependencies"
else
  echo "== Using pip"
  python3 -m ensurepip --upgrade || error_exit "Failed to upgrade pip"
  pip3 install --upgrade setuptools || error_exit "Failed to upgrade setuptools"
  pip3 install ninja cmake wheel pybind11 packaging || error_exit "Failed to install build dependencies"
fi

exit 0
