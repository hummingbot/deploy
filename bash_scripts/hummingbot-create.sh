#!/bin/bash

source "$(dirname "$0")/folder-structure.sh"

# Functions
ask() {
  local prompt=$1
  local default_value=$2

  read -p "$prompt" result
  if [ "$result" == "" ]; then
    echo $default_value
  else
    echo $result
  fi
}

print_folder_structure() {
  local instance_name=$1
  local tag=$2
  local folder=$3

  printf "%30s %5s\n" "Instance name:" "$instance_name"
  printf "%30s %5s\n" "Version:" "hummingbot/hummingbot:$tag"
  echo
  printf "%30s %5s\n" "Main folder path:" "$folder"
  for i in "${!SUB_FOLDERS[@]}"; do
    printf "%30s %5s\n" "${SUB_FOLDER_NAMES[i]} files:" "├── $folder/${SUB_FOLDERS[i]}"
  done
}

prompt_proceed () {
  read -p "   Do you want to proceed? [Y/N] >>> " PROCEED

  if [ "$PROCEED" == "" ]; then
    PROCEED="Y"
  fi
  echo "$PROCEED"
}

# Create folder structure for your new instance
create_folders() {
  local folder="$1"

  for sub_folder in "${SUB_FOLDERS[@]}"; do
    mkdir -p "$folder/$sub_folder"
  done

  for sub_conf_extra in "${SUB_CONF_EXTRAS[@]}"; do
    mkdir -p "$folder/conf/$sub_conf_extra"
  done
}

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

# Call Docker to create a new instance
run_docker() {
  local instance_name=$1
  local tag=$2
  local docker_volume_args=$3

  docker run -it --log-opt max-size=10m --log-opt max-file=5 \
    --name "$instance_name" \
    --network host \
    $docker_volume_args \
    hummingbot/hummingbot:"$tag"
}

# Execute docker commands
create_instance () {
  local instance_name="$1"
  local tag="$2"
  local folder="$3"

  echo
  echo "Creating Hummingbot instance ... Admin password may be required to set the required permissions ..."
  echo

  # 1) Create folder structure for your new instance
  create_folders "$folder"

  # 2) Set required permissions to save hummingbot password the first time
  set_rw_permissions "$folder"

  # 3) Launch a new instance of hummingbot
  DOCKER_VOLUME_ARGS=$(build_docker_volume_args "$folder")
  run_docker "$instance_name" "$tag" "$DOCKER_VOLUME_ARGS"
}

if [ "$1" == "--test" ]; then
  test_function=$2
  $test_function "${@:3}"
  exit 0
fi

main(){
  # Main Execution
  echo
  echo
  echo "===============  CREATE A NEW HUMMINGBOT INSTANCE ==============="
  echo
  echo
  echo "ℹ️  Press [ENTER] for default values:"
  echo

  # Specify hummingbot version
  TAG=$(ask "   Enter Hummingbot version you want to use [latest/development] (default = \"latest\") >>> " "latest")

  # Ask the user for the name of the new instance
  INSTANCE_NAME=$(ask "   Enter a name for your new Hummingbot instance (default = \"hummingbot\") >>> " "hummingbot")
  DEFAULT_FOLDER="${INSTANCE_NAME}_files"

  # Ask the user for the folder location to save files
  FOLDER=$(ask "   Enter a folder name where your Hummingbot files will be saved (default = \"$DEFAULT_FOLDER\") >>> " $DEFAULT_FOLDER)

  if [[ ${FOLDER::1} != "/" ]]; then
    FOLDER=$PWD/$FOLDER
  fi

  echo
  echo "ℹ️  Confirm below if the instance and its folders are correct:"
  echo
  print_folder_structure "$INSTANCE_NAME" "$TAG" "$FOLDER"
  echo

  prompt_proceed
  if [[ "$PROCEED" == "Y" || "$PROCEED" == "y" ]]
  then
    create_instance "$INSTANCE_NAME" "$TAG" "$FOLDER"
  else
    echo "   Aborted"
    echo
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
