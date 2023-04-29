#!/bin/bash
# Source the required files
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh

# Test copy_certs() function
test_copy_certs_start_errors() {
  local test_image="test_image"
  local from_folder="from_folder"
  local to_folder="to_folder"

  # Mock functions
  docker() {
    echo "docker called with arguments: $@"
  }

  source ../bash_scripts/gateway-copy-certs.sh --source-only

  # Run copy_certs() and capture the output
  local result
  result=$(copy_certs_start $test_image $from_folder $to_folder)

  # Check if the copy_certs() errors out on no directory
  local expected_output="❌  Error copying files from from_folder to to_folder"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  from_folder=$(mktemp -d)
  result=$(copy_certs_start $test_image $from_folder $to_folder)

  # Check if the copy_certs() errors out on no dest directory
  local expected_output="❌  Error copying files from $from_folder to $to_folder"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  to_folder=$(mktemp -d)
  result=$(copy_certs_start $test_image "$from_folder" "$to_folder")

  # Check if the copy_certs() errors out on no files to copy
  expected_output="❌  Error copying files from $from_folder to $to_folder"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  file=$(mktemp $from_folder/file.XXXXXX)
  result=$(copy_certs_start $test_image "$from_folder" "$to_folder")

  # Check if the copy_certs() errors out on no files to copy
  expected_output="ℹ️  Files successfully copied from $from_folder to $to_folder"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  expected_output="docker called with arguments: start $test_image"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  expected_output="docker called with arguments: attach $test_image"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  from_listing=$(ls $from_folder)
  to_listing=$(ls $to_folder)
  expected_output="$from_listing"
  if [[ "$to_listing" != *"$expected_output"* ]]; then
    echo "FAIL: test_copy_certs_start() :copy_certs_start() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${to_listing}"
    exit 1
  fi

  rm -rf $from_folder $to_folder

  echo "PASS: create_instance() mocked tests passed"
}

# Test main() function
test_main() {
  source ../bash_scripts/gateway-copy-certs.sh --source-only

  # Mock functions
  ask() {
    if [ "$1" == "Enter Gateway container name (default = \"gateway\") >>> " ]; then
      echo "gateway"
    elif [ "$1" == "Enter path to the Hummingbot certs folder >>> " ]; then
      echo "$TEST_CERTS_FROM_PATH"
    elif [ "$1" == "Enter path to the Gateway certs folder (default = \"./${default_folder}/\") >>> " ]; then
      echo "$TEST_CERTS_TO_PATH"
    elif [ "$1" == "Do you want to proceed? [Y/n] >>> " ]; then
      echo "$TEST_PROCEED"
    fi
  }

  docker() {
    echo "docker called with arguments: $@"
  }

  TEST_CERTS_FROM_PATH=$(mktemp -d)
  TEST_CERTS_TO_PATH=$(mktemp -d)
  TEST_PROCEED="Y"

  touch "$TEST_CERTS_FROM_PATH/test_cert.pem"

  local result
  result=$(main)

  local expected_output="ℹ️  Files successfully copied from $TEST_CERTS_FROM_PATH to $TEST_CERTS_TO_PATH"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_main() :main() did not return the expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  rm -rf $TEST_CERTS_FROM_PATH $TEST_CERTS_TO_PATH
  unset -f ask docker
  echo "PASS: test_main()"
}

# Run tests
test_copy_certs_start_errors
test_main

run_test_cases_gateway_copy_certs() {
  echo "Running test cases for hummingbot-start.sh..."

  test_copy_certs_start_errors
  if [ $? -ne 0 ]; then
    echo "FAIL: test_copy_certs"
    exit 1
  fi

  echo "PASS: all test cases for hummingbot-start.sh"
}

echo
echo "All tests passed."
