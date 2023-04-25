#!/bin/bash

source folder-structure.sh

# Test default values
test_sub_folders() {
  local expected_output="conf logs data pmm-scripts scripts certs"
  local actual_output="${SUB_FOLDERS[*]}"

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_sub_folders(): expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
}

test_sub_folder_names() {
  local expected_output="Config Log Trade and data PMM scripts Scripts Cert"
  local actual_output="${SUB_FOLDER_NAMES[*]}"

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_sub_folder_names(): expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
}

test_sub_conf_extras() {
  local expected_output="connectors strategies"
  local actual_output="${SUB_CONF_EXTRAS[*]}"

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_sub_conf_extras(): expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
}

test_set_rw_permissions() {
  local expected_output="conf certs"
  local actual_output="${SUB_RW_PERMISSIONS[*]}"

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_set_rw_permissions(): expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
}

test_docker_volume_args() {
  local folder="/home/user/hummingbot"
  local expected_output=" -v $folder/${SUB_FOLDERS[0]}:/conf"
  expected_output+=" -v $folder/${SUB_FOLDERS[1]}:/logs"
  expected_output+=" -v $folder/${SUB_FOLDERS[2]}:/data"
  expected_output+=" -v $folder/${SUB_FOLDERS[3]}:/pmm-scripts"
  expected_output+=" -v $folder/${SUB_FOLDERS[4]}:/scripts"
  expected_output+=" -v $folder/${SUB_FOLDERS[5]}:/certs"
  expected_output+=" -v $folder/conf/${SUB_CONF_EXTRAS[0]}:/conf/connectors"
  expected_output+=" -v $folder/conf/${SUB_CONF_EXTRAS[1]}:/conf/strategies"
  local actual_output=$(build_docker_volume_args "$folder")

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_docker_volume_args(): expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
}

# Run the tests
test_sub_folders
test_sub_folder_names
test_sub_conf_extras
test_set_rw_permissions
test_docker_volume_args

run_test_cases_folder_structure() {
    echo "Running test cases for ../bash_scripts/folder_structure.sh"

  test_sub_folders
  if [ $? -ne 0 ]; then
    echo "FAIL: test_sub_folders"
    exit 1
  fi

  test_sub_folder_names
  if [ $? -ne 0 ]; then
    echo "FAIL: test_print_folder_structure"
    exit 1
  fi

  test_sub_conf_extras
  if [ $? -ne 0 ]; then
    echo "FAIL: test_prompt_proceed"
    exit 1
  fi

  test_set_rw_permissions
  if [ $? -ne 0 ]; then
    echo "FAIL: test_create_folders"
    exit 1
  fi

  test_docker_volume_args
  if [ $? -ne 0 ]; then
    echo "FAIL: test_set_rw_permissions"
    exit 1
  fi

  echo "All test cases for ../bash_scripts/hummingbot-create.sh passed"
}