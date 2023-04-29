#!/bin/bash
# =============================================

source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh

# Functions
prompt_gateway_tag() {
  local gateway_tag
  gateway_tag=$(ask "Enter Gateway version you want to use [latest/latest-arm] (default = \"latest\") >>> " "latest")
  echo "$gateway_tag"
}

prompt_instance_name() {
  local instance_name default_folder
  instance_name=$(ask "Enter a name for your new Gateway instance (default = \"gateway\") >>> " "gateway")
  default_folder="${instance_name}_files"
  echo "$instance_name" "$default_folder"
}

prompt_folder() {
  local default_folder folder conf_folder logs_folder certs_folder
  default_folder="$1"
  folder=$(ask "Enter the folder name where your Gateway files will be saved (default = \"$default_folder\") >>> " "$default_folder")
  [[ ${folder::1} != "/" ]] && folder="$PWD/$folder"

  conf_folder="$folder/conf"
  logs_folder="$folder/logs"
  certs_folder="$folder/certs"
  echo "$folder" "$conf_folder" "$logs_folder" "$certs_folder"
}

prompt_passphrase() {
  local passphrase=""
  local attempts=0
  while [ "$passphrase" == "" ]; do
    ((attempts++))
    if [ $attempts -gt 3 ]; then
      print_error "Error: maximum number of attempts exceeded"
      exit 1
    fi
    passphrase=$(ask "Enter the passphrase you used to generate certificates in Hummingbot >>> " "")
    if [ "$passphrase" == "" ]; then
      print_error "Error: passphrase cannot be blank"
    fi
  done
  echo "$passphrase"
}

prompt_existing_certs_path() {
  local certs_folder="$1"
  local certs_path_to_copy
  local attempts=0

  if [ ! -d "$certs_folder" ]; then
    print_error "Error: Invalid argument: >$certs_folder< is not a directory"
    exit 1
  fi

  certs_path_to_copy=$(ask "Enter the path to the folder where Hummingbot certificates are stored >>> " "")
  if [ "$certs_path_to_copy" == "" ]; then
    print_info "After installation, set certificatePath in $certs_folder/server.yml and restart Gateway"
    return 0
  else
    if [ ! -d "$certs_path_to_copy" ]; then
      print_error "Error: $certs_path_to_copy does not exist or is not a directory"
      exit 1
    fi
    cp -r $certs_path_to_copy/* $certs_folder/
    if [ $? -eq 0 ]; then
      print_success "Files successfully copied from $certs_path_to_copy to $certs_folder"
    else
      print_error "Error copying files from $certs_path_to_copy to $certs_folder"
      exit 1
    fi
  fi
}

check_available_port() {
  local initial_port port limit
  initial_port=$1
  port=$initial_port
  limit=$((port + 1000))
  while [[ $port -le $limit ]]; do
    if [[ $(netstat -nat | grep "$port") ]]; then
      ((port = port + 1))
    else
      break
    fi
  done
  echo $port
}

create_instance() {
  local instance_name="$1"
  local gateway_tag="$2"
  local folder="$3"
  local gateway_port="$4"
  local docs_port="$5"
  local passphrase="$6"

  local image_name=${7:-"hummingbot/gateway"}

  if [[ ! -d $folder ]]; then
    print_error "Error: Invalid argument: >$folder< is not a directory"
    exit 1
  fi

  local v_string=""
  for sub_folder in "${GW_SUB_FOLDERS[@]}"; do
    mkdir -p "$folder/$sub_folder"
    v_string+=" -v $folder/$sub_folder:/usr/src/app/$sub_folder"
  done

  set_rw_permissions "$folder"

  prompt_existing_certs_path "$folder/certs"

  docker run -d \
  --name "$instance_name" \
  -p $gateway_port:15888 \
  -p $docs_port:8080 \
  $v_string \
  -e GATEWAY_PASSPHRASE="$passphrase" \
  "$image_name":"$gateway_tag"
}

main() {
  local image_name=${1:-"hummingbot/gateway"}

  print_script_title "CREATE A NEW GATEWAY INSTANCE"

  local gateway_tag
  gateway_tag=$(prompt_gateway_tag)

  local instance_name default_folder
  instance_name=$(prompt_instance_name)

  local folder conf_folder logs_folder certs_folder
  folder=$(prompt_folder "$default_folder")

  local passphrase
  passphrase=$(prompt_passphrase)

  local gateway_port docs_port
  gateway_port=$(check_available_port 15888)
  docs_port=$(check_available_port 8080)

  echo
  print_info "Confirm below if the instance and its folders are correct:"
  echo

  printf "%30s %5s\n" "Gateway instance name:" "$instance_name"
  printf "%30s %5s\n" "Version:" "hummingbot/gateway:$gateway_tag"
  echo
  # printf "%30s %5s\n" "Hummingbot instance ID:" "$HUMMINGBOT_INSTANCE_ID"
  printf "%30s %5s\n" "Gateway conf path:" "$folder/conf"
  printf "%30s %5s\n" "Gateway log path:" "$folder/logs"
  printf "%30s %5s\n" "Gateway certs path:" "$folder/certs"
  printf "%30s %5s\n" "Gateway port:" "$gateway_port"
  printf "%30s %5s\n" "Gateway docs port:" "$docs_port"
  echo

  local proceed
  proceed=$(ask "Do you want to proceed with installation? [Y/N] >>> " "N")
  if [[ "$proceed" == "Y" || "$proceed" == "y" ]]; then
    create_instance "$instance_name" "$gateway_tag" "$folder" "$gateway_port" "$docs_port" "$passphrase" $image_name
  else
    print_info "Aborted"
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
