#!/bin/bash
# =============================================

source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh

# List all docker instances using the same image
list_instances () {
  local tag=$1
  local image_name=${2:-hummingbot/hummingbot}

  print_section_message "List of all docker containers using the \"$tag\" version:"
  docker ps -a --filter ancestor=$image_name:$tag
  print_warning "This will attempt to update all instances. Any containers not in Exited () STATUS will cause the update to fail."
  print_info "TIP: Connect to a running instance using \"./start.sh\" command and \"exit\" from inside Hummingbot."
  print_info "TIP: You can also remove unused instances by running \"docker rm [NAME]\" in the terminal."
  echo
}

# List all directories in the current folder
list_dir () {
  local dir=${1:-$PWD}
  print_section_message "   List of folders in your directory:"
  find "$dir" -mindepth 1 -maxdepth 1 -type d -printf "   📁  %f\n"
  echo
}

# Ask the user for the folder location of each instance
prompt_folder() {
  local instances=("$@")
  local folders=()

  for instance in "${instances[@]}"; do
    local default_folder="${instance}_files"
    [[ "$instance" == "hummingbot-instance" ]] && default_folder="hummingbot_files"

    folder=$(ask "   Enter the destination folder for $instance (default = \"$default_folder\") >>> " "$default_folder")
    [[ ${folder::1} != "/" ]] && folder="$PWD/$folder"

    # Store folder names into an array
    folders+=("$folder")
  done

  echo "${folders[@]}"
}

# Display instances and destination folders then prompt to proceed
confirm_update() {
  local instances_folders=("$@")
  local array_length=${#instances_folders[@]}

  if (( array_length % 2 != 0 )); then
    print_error "The number of instances and folders must be equal. Please check your input."
    return 1
  fi

  local half_length=$(( array_length / 2 ))

  echo
  print_info "Confirm below if the instances and their folders are correct:"
  echo
  printf "%30s %5s %10s\n" "INSTANCE" "         " "FOLDER"
  for ((i=0; i<half_length; i++)); do
    printf "%30s %5s %10s\n" "${instances_folders[$i]}" " ----------> " "${instances_folders[$i + $half_length]}"
  done
  echo
}

remove_docker_containers() {
  local instances=("$@")
  echo "Removing docker containers first ..."
  docker rm "${instances[@]}" | sed 's/^/\t/'
}

delete_docker_image() {
  local image_name=$1
  local tag=$2
  echo "Deleting old image ..."
  docker image rm -f $image_name:$tag | sed 's/^/\t/'
}

create_docker_containers() {
  echo "Creating new docker containers ..."
  local image_name=$1
  local tag=$2

  # Calculate the length of instances and folders arrays
  local array_length=$(($# - 2))
  local half_length=$((array_length / 2))

  if (( array_length % 2 != 0 )); then
    print_error "The number of instances and folders must be equal. Please check your input."
    return 1
  fi

  # Slice the input arguments to get instances and folders arrays
  local instances=("${@:3:$half_length}")
  local folders=("${@:3+$half_length}")

  echo "Re-creating docker containers with updated image ..."
  for ((i=0; i<${#instances[@]}; i++)); do
    # Build the docker volume arguments for the current folder
    local docker_volume_args=$(build_docker_volume_args "${folders[i]}")

    # Run the docker container with the current instance and folder
    run_docker "${instances[i]}" "$tag" "$docker_volume_args" "$image_name"
  done
}

# Execute docker commands
execute_docker() {
  local image_name=$1
  local tag=$2

  local instances_folders=("$@")
  local array_length=${#instances_folders[@]}

  if (( array_length % 2 != 0 )); then
    print_error "The number of instances and folders must be equal. Please check your input."
    return 1
  fi

  local half_length=$(( array_length / 2 ))
  local instances=("${instances_folders[@]:0:$half_length}")
  local folders=("${instances_folders[@]:$half_length}")

  remove_docker_containers "${instances[@]}"
  delete_docker_image $image_name $tag
  create_docker_containers "${instances_folders[@]}"

  print_section_message "Update complete! All running docker instances:"
  docker ps
  echo
  print_info "Run command \"./hummingbot-start.sh\" to connect to an instance."
  echo
}

main(){
  print_script_title "UPDATE HUMMINGBOT INSTANCE"
  TAG=$(ask "   Enter Hummingbot version you want to use [latest/development] (default = \"latest\") >>> " "latest")

  list_instances "$TAG"
  CONTINUE=$(ask "   Do you want to continue? [Y/n] >>> " "Y")

  if [ "$CONTINUE" == "Y" ]; then
    # Store instance names in an array
    declare -a INSTANCES
    INSTANCES=( $(docker ps -a --filter ancestor=hummingbot/hummingbot:$TAG --format "{{.Names}}") )
    list_dir .
    declare -a FOLDERS
    FOLDERS=( $(prompt_folder "${INSTANCES[@]}") )

    echo $(confirm_update "${INSTANCES[@]}" "${FOLDERS[@]}")

    PROCEED=$(ask "   Proceed? [Y/n] >>> " "Y")
    if [ "$PROCEED" == "Y" ]
    then
      execute_docker hummingbot/hummingbot $TAG "${INSTANCES[@]}" "${FOLDERS[@]}"
    else
      echo "   Update aborted"
      echo
    fi
  else
    echo "   Update aborted"
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
