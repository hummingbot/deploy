#!/bin/bash

source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh

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

# Execute docker commands
create_instance () {
  local instance_name="$1"
  local tag="$2"
  local folder="$3"

  print_section_message "Creating Hummingbot instance ... Admin password may be required to set the required permissions ..."

  # 1) Create folder structure for your new instance
  create_folders "$folder"

  # 2) Set required permissions to save hummingbot password the first time
  set_rw_permissions "$folder"

  # 3) Launch a new instance of hummingbot
  local docker_volume_args=$(build_docker_volume_args "$folder")
  run_docker "$instance_name" "$tag" "$docker_volume_args"
}

main(){
  # Main Execution
  print_script_title "CREATE A NEW HUMMINGBOT INSTANCE"

  # Specify hummingbot version
  TAG=$(ask "   Enter Hummingbot version you want to use [latest/development] (default = \"latest\") >>> " "latest")

  # Ask the user for the name of the new instance
  INSTANCE_NAME=$(ask "   Enter a name for your new Hummingbot instance (default = \"hummingbot\") >>> " "hummingbot")
  DEFAULT_FOLDER="${INSTANCE_NAME}_files"

  # Ask the user for the folder location to save files
  FOLDER=$(ask "   Enter a folder name where your Hummingbot files will be saved (default = \"$DEFAULT_FOLDER\") >>> " $DEFAULT_FOLDER)
  [[ ${FOLDER::1} != "/" ]] && FOLDER=$PWD/$FOLDER

  echo
  print_info "Confirm below if the instance and its folders are correct:"
  echo
  print_folder_structure "$INSTANCE_NAME" "$TAG" "$FOLDER"
  echo

  PROCEED=$(ask "   Do you want to proceed? [Y/n] >>> " "Y")
  if [[ "$PROCEED" == "Y" || "$PROCEED" == "y" ]]
  then
    create_instance "$INSTANCE_NAME" "$TAG" "$FOLDER"
  else
    echo "   Aborted"
    echo
  fi
}

### Main Execution ###

# If sourced with --source-only flag, skip the rest of the script
if [ "$1" == "--source-only" ]; then
  return 0
fi

# If called with --test flag, run the specified test function
if [ "$1" == "--test" ]; then
  test_function=$2
  $test_function "${@:3}"
  exit 0
fi

# Otherwise, execute main()
main "$@"
