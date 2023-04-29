#!/bin/bash

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

ask_array() {
  local prompt=$1
  local default_value=$2
  local input_array=("${@:3}")

  local result
  if [ ${#input_array[@]} -gt 0 ]; then
    result="${input_array[0]}"
    input_array=("${input_array[@]:1}")
  else
    read -p "$prompt" result
  fi

  if [ "$result" == "" ]; then
    echo $default_value
  else
    echo $result
  fi

  echo "${input_array[@]}"
}

# Call Docker to create a new instance
run_docker() {
  local instance_name=$1
  local tag=$2
  local docker_volume_args=$3
  local image_name=${4:-hummingbot/hummingbot}
  local background_flag=${5:-"false"}

  if [[ "$background_flag" == "true" ]]; then
    mode="-d"
  else
    mode="-it"
  fi

  docker run $mode --log-opt max-size=10m --log-opt max-file=5 \
    --name "$instance_name" \
    --network host \
    $docker_volume_args \
    $image_name:"$tag"
}

print_script_title() {
  local title=$1
  echo
  echo
  echo "===============  $title ==============="
  echo
  echo
  echo "ℹ️  Press [ENTER] for default values:"
  echo
}

print_section_message() {
  local message=$1
   echo
   echo "$message"
   echo
}

print_warning() {
  local warning=$1
  echo
  echo "⚠️  WARNING: $warning"
  echo
}

print_info() {
  local tip=$1
  echo "ℹ️  $tip"
}

print_success() {
  local success=$1
  echo "✅  $success"
}

print_error() {
  local error=$1
  echo "❌  $error"
}

# For tests
v_string() {
  local folder=$1
  local f_string=("conf" "logs" "data" "pmm-scripts" "scripts" "certs" "conf/connectors" "conf/strategies")

  local v_string=""
  for f_string in "${f_string[@]}"; do
      v_string+=" -v $folder/${f_string}:/${f_string}"
  done

  echo "$v_string"
}


# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0
fi

if [ "$1" == "--test" ]; then
  test_function=$2
  $test_function "${@:3}"
  exit 0
fi
