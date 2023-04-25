#!/bin/bash

source $(dirname "$0")/../bash_scripts/folder_structure.sh

# Test if the user aborts the update process after listing instances
test_abort_after_listing_instances() {
  local input="N"
  local expected_output="Update aborted"
  local actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-update.sh 2>&1 | grep -oP 'Update aborted')

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_abort_after_listing_instances(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi

  echo "PASS: test_abort_after_listing_instances"
}

# Test if the user aborts the update process after confirming instances and folders
test_abort_after_confirming_instances_and_folders() {
  local input="Y\nN"
  local expected_output="Update aborted"
  local actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-update.sh 2>&1 | grep -oP 'Update aborted')

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_abort_after_confirming_instances_and_folders(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi

  echo "PASS: test_abort_after_confirming_instances_and_folders"
}

# Run tests
test_abort_after_listing_instances
test_abort_after_confirming_instances_and_folders

run_test_cases_hummingbot_update() {
    echo "Running test cases for ../bash_scripts/hummingbot-update.sh"

  test_ask
  if [ $? -ne 0 ]; then
    echo "FAIL: test_ask"
    exit 1
  fi

  echo "All test cases for ../bash_scripts/hummingbot-update.sh passed"
}