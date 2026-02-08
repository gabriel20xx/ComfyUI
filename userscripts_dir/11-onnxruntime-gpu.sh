#!/bin/bash

# Pre-requisites (run first):
# - 00-nvidiaDev.sh

# Install onnxruntime-gpu from PyPI
#
# https://onnxruntime.ai/
# https://github.com/microsoft/onnxruntime

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
  echo -e "!! Exiting onnxruntime-gpu Script (ID: $$)"
  exit 1
}

source /comfy/mnt/venv/bin/activate || error_exit "Failed to activate virtualenv"

echo "Checking for existing onnxruntime installations..."

# Check if onnxruntime-gpu is installed
if pip show onnxruntime-gpu > /dev/null 2>&1; then
    # Check if standard onnxruntime (CPU) is ALSO installed
    if pip show onnxruntime > /dev/null 2>&1; then
        # Case: GPU installed AND CPU installed -> Remove both, then install GPU
        echo "${LOG_WARN}Warning:${NC} Found BOTH onnxruntime and onnxruntime-gpu."
        echo "Uninstalling both to ensure clean GPU installation..."
        pip uninstall -y onnxruntime onnxruntime-gpu || error_exit "Failed to uninstall conflicting packages"
    else
        # Case: GPU installed AND CPU NOT installed
        if [ "$FORCE_REINSTALL" = "false" ]; then
            echo "${LOG_INFO}INFO:${NC} onnxruntime-gpu is already installed and clean."
            echo "     (Set FORCE_REINSTALL=true in script to force reinstall)"
            exit 0
        else
            pip uninstall -y onnxruntime-gpu || error_exit "Failed to uninstall onnxruntime-gpu"
        fi
     fi
else
    # Check if standard onnxruntime (CPU) is installed
    if pip show onnxruntime > /dev/null 2>&1; then
        # Case: GPU NOT installed AND CPU installed -> Remove CPU, then install GPU
        echo "${LOG_WARN}Warning:${NC} Found onnxruntime (CPU). Uninstalling it to replace with GPU version..."
        pip uninstall -y onnxruntime || error_exit "Failed to uninstall onnxruntime"
    else
        # Case: GPU NOT installed AND CPU NOT installed -> Install GPU
        echo "${LOG_INFO}INFO:${NC} No conflicting 'onnxruntime' (CPU) package found. Proceeding..."
    fi
fi

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

CMD="${PIP3_CMD} onnxruntime-gpu"
echo "CMD: \"${CMD}\""
${CMD} || error_exit "Failed to install onnxruntime-gpu"
echo "${LOG_OK}SUCCESS:${NC} onnxruntime-gpu installed"

exit 0