#!/bin/bash

# Ordered list of sub-folders to create
       SUB_FOLDERS=(conf     logs  data             pmm-scripts   scripts   certs)
  SUB_FOLDER_NAMES=("Config" "Log" "Trade and data" "PMM scripts" "Scripts" "Cert")

# Ordered list of sub-folders to create
   GW_SUB_FOLDERS=(conf     logs   certs)
  GW_FOLDER_NAMES=("Config" "Log" "Cert")

# List of sub-folders to create in conf/
   SUB_CONF_EXTRAS=(connectors strategies)

# List of sub-folders to set R/W permissions for all
SUB_RW_PERMISSIONS=(conf certs)

# Set R/W permissions for all
set_rw_permissions() {
  local folder="$1"

  for sub_rw_permissions in "${SUB_RW_PERMISSIONS[@]}"; do
    chmod u+rw "$folder/$sub_rw_permissions"
    if [ $? -ne 0 ]; then
      echo "Failed to set permissions. Trying with sudo..."
      sudo chmod a+rw "$folder/$sub_rw_permissions"
    fi
  done
}

build_docker_volume_args() {
    local folder="$1"
    local sub_folders=( "${SUB_FOLDERS[@]}" )
    local sub_conf_extras=( "${SUB_CONF_EXTRAS[@]}" )
    local docker_volume_args=""

    for i in "${!sub_folders[@]}"; do
        docker_volume_args+=" -v $folder/${sub_folders[$i]}:/$(echo "${sub_folders[$i]}")"
    done

    for i in "${!sub_conf_extras[@]}"; do
        docker_volume_args+=" -v $folder/conf/${sub_conf_extras[$i]}:/conf/$(echo "${sub_conf_extras[$i]}")"
    done

    echo "$docker_volume_args"
}

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0
fi
