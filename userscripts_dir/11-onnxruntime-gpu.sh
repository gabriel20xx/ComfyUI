#!/bin/bash

# Pre-requisites (run first):
# - 00-nvidiaDev.sh

# Install onnxruntime-gpu from PyPI
#
# https://onnxruntime.ai/
# https://github.com/microsoft/onnxruntime

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

echo "== PIP3_CMD: \"${PIP3_CMD}\""
if [ "A$use_uv" == "Atrue" ]; then
  echo "== Using uv"
  echo " - uv: $uv"
  echo " - uv_cache: $uv_cache"
else
  echo "== Using pip"
fi

echo "Checking for existing onnxruntime installations..."

# Check if standard onnxruntime (CPU) is installed
if pip show onnxruntime > /dev/null 2>&1; then
    # Check if onnxruntime-gpu is ALSO installed
    if pip show onnxruntime-gpu > /dev/null 2>&1; then
        echo "Found BOTH onnxruntime and onnxruntime-gpu."
        echo "Uninstalling both to ensure clean GPU installation..."
        pip uninstall -y onnxruntime onnxruntime-gpu || error_exit "Failed to uninstall conflicting packages"
    else
        # Only standard onnxruntime is installed
        echo "Found onnxruntime (CPU). Uninstalling it to replace with GPU version..."
        pip uninstall -y onnxruntime || error_exit "Failed to uninstall onnxruntime"
    fi
else
    echo "No conflicting 'onnxruntime' (CPU) package found. Proceeding..."
fi

CMD="${PIP3_CMD} onnxruntime-gpu"
echo "CMD: \"${CMD}\""
${CMD} || error_exit "Failed to install onnxruntime-gpu"

exit 0