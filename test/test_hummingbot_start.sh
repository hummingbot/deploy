#!/bin/bash
# =============================================
# Tests for hummingbot-start.sh

source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh

setup_startup() {
  local -n arr=$1

  # Create a temporary directory for testing
  test_dir=$(mktemp -d)

  # Prepare a unique instance name for testing
  instance_name="hummingbot-test-$(cat /proc/sys/kernel/random/uuid)"

  # Remove the container if it already exists
  if docker ps -a --format "{{.Names}}" | grep -Eq "^${instance_name}$"; then
    docker rm -f "$instance_name" >/dev/null 2>&1
  fi

  # Build a test image
  local dockerfile=$(cat <<EOF
FROM alpine:3.14
CMD sleep 10
EOF
  )
  docker build -t "$instance_name" - <<<"$dockerfile" >/dev/null 2>&1

  arr=($test_dir $instance_name)
}

function cleanup() {
  local -n arr=$1

  local test_dir=${arr[0]}
  local container_name=${arr[1]}

  # Stop and remove the hummingbot container if it's running
  if docker ps --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
    docker stop "$container_name" >/dev/null 2>&1
    docker rm "$container_name" >/dev/null 2>&1
  fi

  if [[ $test_dir =~ "/tmp/tmp."* ]]; then
    rm -rf "$test_dir"
  fi
}

function test_list_instances() {
  # Test that the list_instances function lists all containers
  local setup_array
  setup_startup setup_array

  local test_dir=${setup_array[0]}
  local container_name=${setup_array[1]}

  docker run -d --name "$container_name" alpine >/dev/null

  # Run the function and check if it lists the new container
  output=$(../bash_scripts/hummingbot-start.sh --test list_instances)

  if ! echo "$output" | grep -q "${container_name}"; then
    echo "FAIL: list_instances(): did not list new container"
    cleanup setup_array
    exit 1
  fi

  # Cleanup
  cleanup setup_array
  echo "PASS: list_instances()"
}

function test_start_docker() {
  # Test that the start_docker function starts the container and attaches to it
  # First, start a new container with a random name and a sleep command
  local setup_array
  setup_startup setup_array

  local test_dir=${setup_array[0]}
  local container_name=${setup_array[1]}

  docker run -d --name "$container_name" alpine sleep 10 >/dev/null

  # Run the function and check if it attaches to the container
  output=$(../bash_scripts/hummingbot-start.sh --test start_docker "$container_name" "test")
  if ! echo "$output" | grep -q "  --> Successfully started and attached to container $container_name"; then
    echo "FAIL: start_docker(): did not attach to container"
    cleanup setup_array
    exit 1
  fi

  # Cleanup
  cleanup setup_array
  echo "PASS: start_docker()"
}

# Run the tests
test_list_instances
test_start_docker

run_test_cases_hummingbot_start() {
  echo "Running test cases for hummingbot-start.sh..."

  test_list_instances
  if [ $? -ne 0 ]; then
    echo "FAIL: test_list_instances"
    exit 1
  fi

  test_start_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_start_docker"
    exit 1
  fi

  echo "PASS: all test cases for hummingbot-start.sh"
}
