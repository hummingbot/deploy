#!/bin/bash

source $(dirname "$0")/../bash_scripts/folder-structure.sh

# Test default values
test_ask() {
  # Test default value
  DEFAULT_VALUE=$(echo "" | ../bash_scripts/hummingbot-common.sh --test ask "Enter a value (default = \"default_value\") >>> " "default_value")
  if [ "$DEFAULT_VALUE" != "default_value" ]; then
    echo "FAIL: ask(): Default value should be 'default_value'"
    exit 1
  fi

  # Test custom value
  CUSTOM_VALUE=$(echo "custom_value" | ../bash_scripts/hummingbot-common.sh --test ask "Enter a value (default = \"default_value\") >>> " "default_value")
  if [ "$CUSTOM_VALUE" != "custom_value" ]; then
    echo "FAIL: ask(): Custom value should be 'custom_value'"
    exit 1
  fi
  echo "PASS: ask()"
}

test_ask_array() {
  # Test default value
  local DEFAULT_VALUES=("default_value1" "default_value2")
  local DEFAULT_VALUES_STRING=$(echo "" | ../bash_scripts/hummingbot-common.sh --test ask_array "Enter comma-separated values for default values (default = \"${DEFAULT_VALUES[*]}\") >>> " "${DEFAULT_VALUES[*]}")
  read -ra DEFAULT_VALUES_ACTUAL <<< "$DEFAULT_VALUES_STRING"
  if [ "${DEFAULT_VALUES_ACTUAL[*]}" != "${DEFAULT_VALUES[*]}" ]; then
    echo "FAIL: ask_array(): Default values should be '${DEFAULT_VALUES[*]}'"
    exit 1
  fi

  # Test custom value
  local CUSTOM_VALUES=("custom_value1" "custom_value2")
  local CUSTOM_VALUES_STRING=$(echo "${CUSTOM_VALUES[*]}" | ../bash_scripts/hummingbot-common.sh --test ask_array "Enter comma-separated values for custom values (default = \"${DEFAULT_VALUES[*]}\") >>> " "${DEFAULT_VALUES[*]}")
  read -ra CUSTOM_VALUES_ACTUAL <<< "$CUSTOM_VALUES_STRING"
  if [ "${CUSTOM_VALUES_ACTUAL[*]}" != "${CUSTOM_VALUES[*]}" ]; then
    echo "FAIL: ask_array(): Custom values should be '${CUSTOM_VALUES[*]}'"
    exit 1
  fi
  echo "PASS: ask_array()"
}

test_prompt_proceed() {
  local input="Y"
  local expected_output="Y"
  local actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-common.sh --test ask "   Do you want to proceed? [Y/n] >>> " "Y")

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_prompt_proceed(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi

  input="N"
  expected_output="N"
  actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-common.sh --test ask "   Do you want to proceed? [Y/n] >>> " "Y")

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_prompt_proceed(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi

  input=""
  expected_output="Y"
  actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-common.sh --test ask "   Do you want to proceed? [Y/n] >>> " "Y")

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_prompt_proceed(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
  echo "PASS: prompt_proceed()"
}

cleanup() {
  docker rm -f "$container_name" >/dev/null
  docker image rm "$image_name:$tag" >/dev/null
  rm -rf "$test_folder"
  rm -rf "$build_context"
}

test_run_docker() {
  # Create a test folder and file
  local test_folder=$(mktemp -d)
  echo "Test file content" > "$test_folder/test-file.txt"

  # Prepare container name
  local container_name="test-container"

  # Check and remove the existing container with the same name
  if docker ps -a --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
    docker rm -f "$container_name" >/dev/null
  fi

  # Create a build context directory and copy the progress script and Dockerfile into it
  local build_context=$(mktemp -d)
  echo "FROM alpine" > "$build_context/Dockerfile"
  echo "COPY test-file.txt /test-file.txt" >> "$build_context/Dockerfile"
  echo "CMD [\"sleep\", \"infinity\"]" >> "$build_context/Dockerfile"
  cp "$test_folder/test-file.txt" "$build_context/test-file.txt"

  # Create a test image
  local image_name="test-image"
  local tag="latest"
  docker build -t "$image_name:$tag" "$build_context" > /dev/null

  # Start the container
  ../bash_scripts/hummingbot-common.sh --test run_docker "$container_name" "$tag" "-v $test_folder:/test-folder" "$image_name" "true" >/dev/null

  # Wait for the container to start running
  timeout=30
  while [ $timeout -gt 0 ] && ! docker ps --format "{{.Names}}" | grep -q "$container_name"; do
    sleep 1
    timeout=$((timeout - 1))
  done

  # Check if the container is running
  if [ $timeout -eq 0 ]; then
    echo "FAIL: run_docker(): container not running"
    cleanup
    exit 1
  fi

  # Check that the container exists and has the test file
  if ! docker ps -a --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
    echo "FAIL: run_docker(): container not created"
    cleanup
    exit 1
  fi
  if ! docker exec -it "$container_name" sh -c "cat /test-folder/test-file.txt" | grep -q "Test file content"; then
    echo "FAIL: run_docker(): test file not found in container"
    cleanup
    exit 1
  fi

  # Cleanup
  cleanup

  echo "PASS: run_docker() - live"
}

test_run_docker_it() {
  # Create a test folder and file
  local test_folder=$(mktemp -d)
  echo "Test file content" > "$test_folder/test-file.txt"

  # Prepare container name
  local container_name="test-container"

  # Check and remove the existing container with the same name
  if docker ps -a --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
    docker rm -f "$container_name" >/dev/null
  fi

  # Create a build context directory and copy the progress script and Dockerfile into it
  local build_context=$(mktemp -d)
  echo "FROM alpine" > "$build_context/Dockerfile"
  echo "COPY test-file.txt /test-file.txt" >> "$build_context/Dockerfile"
  echo "CMD [\"/bin/sh\", \"-c\", \"time sleep 5 > /test-folder/output.txt 2>&1\"]" >> "$build_context/Dockerfile"
  cp "$test_folder/test-file.txt" "$build_context/test-file.txt"

  # Create a test image
  local image_name="test-image"
  local tag="latest"
  docker build -t "$image_name:$tag" "$build_context" > /dev/null

  # Start timing
  local start_time=$(date +%s.%N)

  # Start the container
  ../bash_scripts/hummingbot-common.sh --test run_docker "$container_name" "$tag" "-v $test_folder:/test-folder" "$image_name" >/dev/null

  # End timing
  local end_time=$(date +%s.%N)

  # Calculate duration
  local duration=$(echo "$end_time - $start_time" | bc)

  # Check how long the container was running
  if [ -f "$test_folder/output.txt" ]; then
    runtime=$(grep real "$test_folder/output.txt" | cut -ds -f1 | cut -dm -f2 | awk '{print $1}')
    expected_runtime="5."
    if [[ ! $runtime =~ ^$expected_runtime ]]; then
      echo "FAIL: run_docker_it(): runtime ($runtime) does not match expected runtime ($expected_runtime)"
      cleanup
      exit 1
    fi
    if (( $(echo "5.5 < $duration" | bc -l) )) ||
       (( $(echo "$duration < $runtime" | bc -l) )) ||
       (( $(echo "$runtime < 5" | bc -l) )); then
      echo "FAIL: run_docker_it(): This assertion is false: 5.5 < $duration < $runtime < 5"
      cleanup
      exit 1
    fi
  else
    echo "FAIL: run_docker_it(): output file not found"
    cleanup
    exit 1
  fi

  # Cleanup
  cleanup

  echo "PASS: run_docker() -  interactive live"
}

# Run the tests
test_ask
test_ask_array
test_prompt_proceed
test_run_docker
test_run_docker_it

run_test_cases_hummingbot_common() {
  echo "Running test cases for ../bash_scripts/hummingbot-common.sh"

  test_ask
  if [ $? -ne 0 ]; then
    echo "FAIL: test_ask"
    exit 1
  fi

  test_ask_array
  if [ $? -ne 0 ]; then
    echo "FAIL: test_ask_array"
    exit 1
  fi

  test_prompt_proceed
  if [ $? -ne 0 ]; then
    echo "FAIL: test_prompt_proceed"
    exit 1
  fi

  test_run_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_run_docker"
    exit 1
  fi

  test_run_docker_it
  if [ $? -ne 0 ]; then
    echo "FAIL: test_run_docker_it"
    exit 1
  fi

  echo "All test cases for ../bash_scripts/hummingbot-common.sh passed"
}