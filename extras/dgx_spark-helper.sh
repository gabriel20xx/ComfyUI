#!/bin/bash

# Adapted from instructions seen on
# https://forums.developer.nvidia.com/t/unlocking-the-power-of-the-spark-in-comfyui-no-crashes/360336

## Fix 1: Disable Swap (Critical)
# This forces a clean OOM kill instead of a silent system freeze. On unified memory, swap is actively harmful.
sudo swapoff -a

## Fix 2: Cap GPU Clocks (Critical)
# This limits the max GPU clock to 2100 MHz (down from 2418/3003). Keeps power draw at ~50W instead of 85W. You can experiment with higher values — 1800 MHz was rock solid, 2100 MHz is the sweet spot for my unit.
sudo nvidia-smi -lgc 300,2100

## GPU stability
# Persistence mode
sudo nvidia-smi -pm 1

## Monitoring Script
# background thermal monitor that logs every 5 seconds — invaluable for diagnosing crashes after the fact since the system gives you zero error output:
while true; do
    TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits)
    MEM_USED=$(free -g | grep Mem | tr -s " " | cut -d " " -f 4)
    MEM_TOTAL=$(free -g | grep Mem | tr -s " " | cut -d " " -f 2)
    SWAP_USED=$(free -g | grep Swap | tr -s " " | cut -d " " -f 3)
    echo "$(date +%H:%M:%S) GPU=${TEMP}°C PWR=${POWER}W RAM=${MEM_USED}/${MEM_TOTAL}G SWAP=${SWAP_USED}G" | tee -a thermal_monitor.log
    sleep 5
done

# We should never be here (while true)
