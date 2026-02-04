#!/bin/bash

# Start the timer (using date for compatibility)
START_TIME=$(date +%s)

# Script that installs picklescan package and runs a scan.
# Picklescan is a security scanner detecting Python Pickle files (e.g. .pt files) performing suspicious actions.
# Github shows plenty of resources on the risks: https://github.com/mmaitre314/picklescan
# Since there are still so many .pt files circulating and in use (e.g. Ultralytics), they should be scanned regularly.
# 
# !!NOTE: This is a first line of defense, and isn't flawless. Best protection is to not use picke files at all !!
#
# Outputs result to console and with commented info to a logfile in dockerscripts dir (overwrites)
#
# Can safely be kept in the userscripts dir to scan each time, or just once in a while activate it manually.
# Scans entire /basedir due to some custom nodes putting models in their own custom_node app directory
# If that takes too long, it falls back to just /basedir/models (no timeout)


# --- CONFIGURATION ---
TARGET_DIR="/basedir"
FALLBACK_DIR="/basedir/models"
SCAN_TIMEOUT=15       # Set timeout to your wishes; Scanning 200 files takes about 10s
FAIL_ON_THREATS=true  # Set to false if you want to continue docker startup
# ---------------------

set -e

# --- COLOR CODES (for console)---
RED=$(printf '\033[0;41m') # White on RED BG
# RED=$(printf '\033[0;91m') # Red on Black BG
YELLOW=$(printf '\033[0;33m')
GREEN=$(printf '\033[0;32m')
BLINK=$(printf '\033[0;6m')
NC=$(printf '\033[0m') # No Color


error_exit() {
  echo -n -e "${RED}!! ERROR: "
  echo $*
  echo -e "!! Exiting Picklescan Script (ID: $$)${NC}"
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

# 1. Install picklescan
CMD="${PIP3_CMD} picklescan"
echo "CMD: \"${CMD}\""
${CMD} > /dev/null 2>&1 || error_exit "Failed to install picklescan"

# 2. Run picklescan and log output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/picklescan_output.txt"


echo "== Running picklescan...${NC}"
echo " - Target: ${TARGET_DIR}"
echo " - Fallback Target: ${FALLBACK_DIR}"
echo " - Timeout: ${SCAN_TIMEOUT}s"
echo " - Log: ${LOG_FILE}"
echo "..."

# --- Write Header to Log File ---
cat <<EOF > "${LOG_FILE}"
# Picklescan by MMaitre314 
# Security scanner detecting Python Pickle files performing suspicious actions.
# More info: https://github.com/mmaitre314/picklescan
# Default Scanning entire basedir due to some custom nodes putting models in their own custom_node app directory
# Modify as wished. Scan is quick enough to not cause noticable downtime.
# -------------------------------------
# Scan results; Scroll to end for summary:
#
EOF

# --- Run Scan , log to File ONLY (avoiding 'harmless' warning messages cluttering console) ---

# Enable pipefail: if 'timeout' fails, the whole pipe fails
set -o pipefail

# Disable 'set -e' so we can handle exit code of picklescan process manually
set +e 

# Run the main scan with a timeout
# Redirect stdout/stderr to log file.
timeout "${SCAN_TIMEOUT}" picklescan --path "${TARGET_DIR}" >> "${LOG_FILE}" 2>&1
EXIT_CODE=$?

# Check the result
if [ $EXIT_CODE -eq 124 ]; then
    # 124 = Timeout
    
    # 1. Write clean text to log
    echo "!! Scan timed out (> ${SCAN_TIMEOUT}s)." >> "${LOG_FILE}"
    # 2. Write color to console
    echo "${YELLOW}!! Scan timed out (> ${SCAN_TIMEOUT}s).${NC}"
    echo "!! Modify script to extend timeout or run manually inside container venv:" | tee -a "${LOG_FILE}"
    echo "!! picklescan --path ${TARGET_DIR} " | tee -a "${LOG_FILE}"
    echo "!! Switching to fallback directory (no timeout): ${FALLBACK_DIR}" | tee -a "${LOG_FILE}"
    
    # Run the fallback scan
    picklescan --path "${FALLBACK_DIR}" >> "${LOG_FILE}" 2>&1
    FALLBACK_CODE=$?
    
    # Check Fallback Result
    if [ $FALLBACK_CODE -ne 0 ] && [ $FALLBACK_CODE -ne 1 ]; then
         # Write clean to log
         echo "!! Warning: Fallback scan returned unusual exit code: $FALLBACK_CODE" >> "${LOG_FILE}"
         # Write color to console
         echo "${YELLOW}!! Warning: Fallback scan returned unusual exit code: $FALLBACK_CODE${NC}"
    fi

elif [ $EXIT_CODE -ne 0 ] && [ $EXIT_CODE -ne 1 ]; then
    # If it failed with something other than 0 (Success) or 1 (Threats Found)
	  # Write clean to log
    echo "!! Warning: Main scan returned unusual exit code: $EXIT_CODE" >> "${LOG_FILE}"
	  # Write color to console
    echo "${YELLOW}!! Warning: Main scan returned unusual exit code: $EXIT_CODE${NC}"
fi

# Re-enable 'set -e'
set -e

# --- ANALYZE RESULTS & PRINT SUMMARY TO CONSOLE ---

# Extract counts from log file (default to 0 if not found)
INFECTED_COUNT=$(grep "Infected files:" "${LOG_FILE}" | awk '{print $3}')
GLOBALS_COUNT=$(grep "Dangerous globals:" "${LOG_FILE}" | awk '{print $3}')

# Ensure variables are numbers (handle empty grep results)
INFECTED_COUNT=${INFECTED_COUNT:-0}
GLOBALS_COUNT=${GLOBALS_COUNT:-0}

echo "----------- SCAN SUMMARY -----------"
grep "Scanned files:" "${LOG_FILE}" || echo "Scanned files: 0"

# Print Infected Files (Red if > 0, else Green)
if [ "$INFECTED_COUNT" -gt 0 ]; then
    echo -e "${RED}Infected files: ${INFECTED_COUNT}${NC}"
else
    echo -e "${GREEN}Infected files: ${INFECTED_COUNT}${NC}"
fi

# Print Dangerous Globals (Red if > 0, else Green)
if [ "$GLOBALS_COUNT" -gt 0 ]; then
    echo -e "${RED}Dangerous globals: ${GLOBALS_COUNT}${NC}"
else
    echo -e "${GREEN}Dangerous globals: ${GLOBALS_COUNT}${NC}"
fi

# --- Calculate Duration ---
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$(($DURATION / 60))
SECS=$(($DURATION % 60))
TIME_MSG="Total execution time: ${MINUTES}m ${SECS}s"

# --- Append Footer to Log File ---
cat <<EOF >> "${LOG_FILE}"
# ------------------------
# ${TIME_MSG}
# You can (probably) safely ignore 'Warning: could not parse ...' messages.
# You should NOT ignore 'infected' or 'dangerous globals' messages.
# No support given on this scan script; for scan issues visit the Picklescan github.
# For Pickle issues or false positives; contact Picklescan github or offending file owner.
EOF

echo "saved detailed scan results to ${LOG_FILE}"
echo "${TIME_MSG}"

# --- EXIT LOGIC ---
if [ "$FAIL_ON_THREATS" = "true" ]; then
    if [ "$INFECTED_COUNT" -gt 0 ] || [ "$GLOBALS_COUNT" -gt 0 ]; then
        exit 1
    fi
fi

exit 0