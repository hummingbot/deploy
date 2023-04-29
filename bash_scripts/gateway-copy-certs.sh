#!/bin/bash
# =============================================
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh

copy_certs_start() {
  local instance_name="$1"
  local certs_from_path="$2"
  local certs_to_path="$3"

  cp -r "$certs_from_path"/* "$certs_to_path/" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    print_info "Files successfully copied from $certs_from_path to $certs_to_path"
  else
    print_error "Error copying files from $certs_from_path to $certs_to_path"
    exit 1
  fi

  docker start "$instance_name" && docker attach "$instance_name"
  echo
  echo
}

main() {
  print_script_title "COPY CERTS TO GATEWAY FOLDER"

  local instance_name=$(ask "Enter Gateway container name (default = \"gateway\") >>> " "gateway")

  local certs_from_path=$(ask "Enter path to the Hummingbot certs folder >>> ")
  if [ ! -d "$certs_from_path" ]; then
    print_error "Error: $certs_from_path is not a valid directory"
    exit 1
  fi
  default_folder="${instance_name}_files/certs"
  local folder=$(ask "Enter path to the Gateway certs folder (default = \"./${default_folder}/\") >>> " "$default_folder")
  [[ ${folder::1} != "/" ]] && folder="$PWD/$folder"

  echo
  print_info "Confirm if this is correct:"
  echo
  printf "%30s %5s\n" "Copy certs FROM:" "$certs_from_path"
  printf "%30s %5s\n" "Copy certs TO:" "$folder"
  echo

  local proceed=$(ask "Do you want to proceed? [Y/n] >>> " "Y")

  if [[ "$proceed" == "Y" || "$proceed" == "y" ]]; then
    copy_certs_start "$instance_name" "$certs_from_path" "$folder"
  else
    print_info "Exiting..."
    exit 1
  fi
}

### Main Execution ###

if [ "$1" == "--source-only" ]; then
  return 0
fi

if [ "$1" == "--test" ]; then
  test_function=$2
  $test_function "${@:3}"
  exit 0
fi

main "${@}"
