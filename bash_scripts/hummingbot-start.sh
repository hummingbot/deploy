#!/bin/bash
# =============================================

source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh

list_instances () {
  print_section_message "List of all docker instances:"
  docker ps -a
  echo
}

start_docker() {
  local instance_name=$1
  local test_mode=$2

  if docker start $instance_name && docker attach $instance_name; then
    echo "  --> Successfully started and attached to container $instance_name"
    [ "$test_mode" == "test" ] && docker stop $instance_name
  else
    echo "  x Failed to start or attach to container $instance_name"
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

main() {
  print_script_title "START HUMMINGBOT INSTANCE"
  list_instances
  echo
  INSTANCE_NAME=$(ask "   Enter the NAME of the Hummingbot instance to start or connect to (default = \"hummingbot\") >>> " "hummingbot")
  echo
  # =============================================
  # EXECUTE SCRIPT
  start_docker $INSTANCE_NAME
}
