#!/bin/bash
# Source the required files
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/hummingbot-common.sh
source $(dirname "${BASH_SOURCE[0]}")/../bash_scripts/folder-structure.sh

# Test check_available_port function
test_prompt_gateway_tag() {
  local result
  result=$(echo "" | ../bash_scripts/gateway-create.sh --test prompt_gateway_tag)
  local expected_output="latest"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  result=$(echo "TaG" | ../bash_scripts/gateway-create.sh --test prompt_gateway_tag)
  local expected_output="TaG"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  echo "PASS: prompt_gateway_tag()"
}

test_prompt_folder() {
  local result
  result=$(echo "" | ../bash_scripts/gateway-create.sh --test prompt_folder "default_folder")
  local expected_output="$PWD/default_folder $PWD/default_folder/conf $PWD/default_folder/logs $PWD/default_folder/certs"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  result=$(echo "" | ../bash_scripts/gateway-create.sh --test prompt_folder "/custom/folder")
  local expected_output="/custom/folder /custom/folder/conf /custom/folder/logs /custom/folder/certs"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  result=$(echo "" | ../bash_scripts/gateway-create.sh --test prompt_folder "custom/folder")
  local expected_output="$PWD/custom/folder $PWD/custom/folder/conf $PWD/custom/folder/logs $PWD/custom/folder/certs"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  echo "PASS: prompt_folder()"
}

test_prompt_instance_name() {
  local result
  result=$(echo "" | ../bash_scripts/gateway-create.sh --test prompt_instance_name)
  local expected_output="gateway gateway_files"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  result=$(echo "GaTeWaY" | ../bash_scripts/gateway-create.sh --test prompt_instance_name)
  local expected_output="GaTeWaY GaTeWaY_files"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  echo "PASS: prompt_instance_name()"
}

test_prompt_passphrase() {
  source ../bash_scripts/gateway-create.sh --source-only
  local result

  # No real way to test the interaction of a blank enter key press
  result=$(echo "" | prompt_passphrase)
  local expected_output="\
❌  Error: passphrase cannot be blank
❌  Error: passphrase cannot be blank
❌  Error: passphrase cannot be blank
❌  Error: maximum number of attempts exceeded"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  result=$(echo "1234" | prompt_passphrase)
  local expected_output="1234"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  echo "PASS: prompt_passphrase()"
}

test_prompt_existing_certs_path() {
  local result

  # Test invalid path input
  result=$(echo "" | ../bash_scripts/gateway-create.sh --test prompt_existing_certs_path "/invalid/path")
  local expected_output="\
❌  Error: Invalid argument: >/invalid/path< is not a directory"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  # Test empty input certs directory
  local test_folder=$(mktemp -d)
  result=$(echo | ../bash_scripts/gateway-create.sh --test prompt_existing_certs_path "$test_folder")
  local expected_output="ℹ️  After installation, set certificatePath in $test_folder/server.yml and restart Gateway"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  # Test non-existent path input
  result=$(echo "/nonexistent/path" | ../bash_scripts/gateway-create.sh --test prompt_existing_certs_path "$test_folder")
  local expected_output="\
❌  Error: /nonexistent/path does not exist or is not a directory"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  # Test valid path input
  local certs_folder=$(mktemp -d)
  local certs_path=$(mktemp -d)
  echo "Test file content" > "$certs_path/test-file.txt"
  result=$(echo "$certs_path" | ../bash_scripts/gateway-create.sh --test prompt_existing_certs_path "$certs_folder")
  local expected_output="✅  Files successfully copied from $certs_path to $certs_folder"

  if [[ ! "${result}" == "${expected_output}" ]]; then
    echo "Expected:"
    echo "${expected_output}"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi
  # Cleanup
  rm -rf "$test_folder"

  echo "PASS: prompt_existing_certs_path()"
}

test_check_available_port() {
  local output

  # Open a temporary port to simulate an occupied port
  python3 -m http.server 15888 >/dev/null 2>&1 &
  local python_pid=$!

  output=$(../bash_scripts/gateway-create.sh --test check_available_port 15888)
  if [[ "$output" -le 15888 ]]; then
    echo "FAIL: check_available_port(): returned port $output should be > 15888"
    exit 1
  fi

  # Test the case when the specified base port is free
  output=$(../bash_scripts/gateway-create.sh --test check_available_port 15889)
  if [[ "$output" -ne 15889 ]]; then
    echo "FAIL: check_available_port(): returned port $output should be == 15889"
    exit 1
  fi

  # Close the temporary port
  kill $python_pid

  echo "PASS: check_available_port()"
}

test_check_available_port_mocked_netstat() {
  local output

  source ../bash_scripts/gateway-create.sh --source-only

  # Mock netstat function
  mock_netstat() {
    case $1 in
      -nat)
        for port in {15888..15899}; do
          echo "mocked output for occupied port $port"
        done
        ;;
      *)
        echo "unexpected input to mock_netstat(): $1"
        exit 1
        ;;
    esac
    local port=$1
    if [[ $port -ge 15888 && $port -lt 15900 ]]; then
      echo "mocked output for occupied port $port"
    else
      echo ""
    fi
  }

  # Save original netstat function
  original_netstat=$(declare -f netstat)

  # Replace netstat function with the mock function
  eval "netstat() { mock_netstat \$1; }"

  # Test when all ports within the range 15888-15899 are occupied
  output=$(check_available_port 15888)
  if [[ "$output" -ne 15900 ]]; then
    echo "FAIL: check_available_port_with_mocked_netstat(): returned port $output should be == 15900"
    exit 1
  fi

  # Restore original netstat function
  eval "$original_netstat"
  unset original_netstat

  echo "PASS: check_available_port_with_mocked_netstat()"
}

test_create_instance_mocked() {
  local instance_name="test_instance"
  local gateway_tag="latest"
  local folder=$(mktemp -d)
  local gateway_port="15888"
  local docs_port="8080"
  local passphrase="test_passphrase"
  local test_image_name="test_image"
  local result

  source ../bash_scripts/gateway-create.sh --source-only

  # Mock functions
  set_rw_permissions() {
    echo "set_rw_permissions called with: $1"
  }

  prompt_existing_certs_path() {
    echo "prompt_existing_certs_path called with: $1"
  }

  docker() {
    echo "docker called with: $@"
  }

  # Test successful instance creation
  result=$(create_instance "$instance_name" "$gateway_tag" "$folder" "$gateway_port" "$docs_port" "$passphrase")

  if [[ "$result" != *"set_rw_permissions called with: $folder"* ]]; then
    echo "FAIL: create_instance() :set_rw_permissions not called correctly"
    echo "Expected:"
    echo "set_rw_permissions called with: $folder"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  if [[ "$result" != *"prompt_existing_certs_path called with: $folder/certs"* ]]; then
    echo "FAIL: create_instance() :prompt_existing_certs_path not called correctly"
    echo "Expected:"
    echo "prompt_existing_certs_path called with: $folder/certs"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  expected_output="\
docker called with: run -d --name $instance_name -p $gateway_port:15888 -p $docs_port:8080 \
-v $folder/conf:/usr/src/app/conf \
-v $folder/logs:/usr/src/app/logs \
-v $folder/certs:/usr/src/app/certs \
-e GATEWAY_PASSPHRASE=$passphrase \
hummingbot/gateway:$gateway_tag"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: create_instance() :docker not called correctly"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  # Test successful instance creation with image name
  result=$(create_instance "$instance_name" "$gateway_tag" "$folder" "$gateway_port" "$docs_port" "$passphrase" "$test_image_name")
  expected_output="\
docker called with: run -d --name $instance_name -p $gateway_port:15888 -p $docs_port:8080 \
-v $folder/conf:/usr/src/app/conf \
-v $folder/logs:/usr/src/app/logs \
-v $folder/certs:/usr/src/app/certs \
-e GATEWAY_PASSPHRASE=$passphrase \
$test_image_name:$gateway_tag"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: create_instance() :docker not called correctly"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  # Test invalid folder
  result=$(create_instance "$instance_name" "$gateway_tag" "/nonexistent" "$gateway_port" "$docs_port" "$passphrase" 2>&1)
  if [[ "$result" != *"❌  Error: Invalid argument: >/nonexistent< is not a directory"* ]]; then
    echo "FAIL: create_instance() :failed to handle invalid folder"
    echo "Expected:"
    echo "❌  Error: Invalid argument: >/nonexistent< is not a directory"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

  # Test created folder structure
  for sub_folder in "${GW_SUB_FOLDERS[@]}"; do
    if [[ ! -d "$folder/$sub_folder" ]]; then
      echo "FAIL: create_instance() :failed to create the correct folder structure"
      echo "Missing folder: $folder/$sub_folder"
      exit 1
    fi
  done

  # Cleanup
  unset -f set_rw_permissions prompt_existing_certs_path docker
  rm -rf "$folder"

  echo "PASS: create_instance() mocked tests passed"
}

test_create_instance() {
  local instance_name="test_instance-0"
  local gateway_tag="latest"
  local folder=$(mktemp -d)
  local gateway_port=$(../bash_scripts/gateway-create.sh --test check_available_port "15888")
  local docs_port=$(../bash_scripts/gateway-create.sh --test check_available_port "8080")
  local passphrase="test_passphrase"
  local test_image_name="test-image-0"
  local result

  source ../bash_scripts/gateway-create.sh --source-only

  mkdir -p "$folder/certs" "$folder/conf" "$folder/logs"
  chmod +rw "$folder/certs" "$folder/conf" "$folder/logs"

  build_test_image() {
    local build_context=$(mktemp -d)
    cat << EOF > $build_context/Dockerfile.test
FROM alpine:3.14
CMD ["sh", "-c", "echo 'Test image is running' && sleep 3600"]
EOF

    docker build -t "$test_image_name" -f $build_context/Dockerfile.test $build_context > /dev/null 2>&1
    rm -r $build_context
  }

  cleanup(){
    docker stop "$instance_name" > /dev/null 2>&1
    docker rm -f "$instance_name" > /dev/null 2>&1
    docker rmi "$test_image_name" > /dev/null 2>&1
    rm -rf "$folder"
  }

  # Mock functions
  set_rw_permissions() {
    echo "set_rw_permissions called with: $1"
  }

  prompt_existing_certs_path() {
    echo "prompt_existing_certs_path called with: $1"
  }

  # Test successful instance creation
  build_test_image
  result=$(create_instance "$instance_name" "$gateway_tag" "$folder" "$gateway_port" "$docs_port" "$passphrase" "$test_image_name")
  expected_output=""
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: create_instance() :docker not called correctly"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    cleanup
    exit 1
  fi

  # Give Docker some time to start the container
  sleep 5

  # Check if the container is running
  if ! docker ps --filter "name=$instance_name" --format "{{.Names}}" | grep -q "$instance_name"; then
    echo "FAIL: live_test_create_instance() :instance is not running"
    cleanup
    exit 1
  fi

  # Check if the container logs contain the expected message
  local expected_output="Test image is running"
  local container_logs=$(docker logs "$instance_name")
  if [[ "$container_logs" != *"$expected_output"* ]]; then
    echo "FAIL: live_test_create_instance() :container logs do not match expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${container_logs}"
    cleanup
    exit 1
  fi

  # Check if the folders are mounted correctly
  for sub_folder in "${GW_SUB_FOLDERS[@]}"; do
    local host_folder="$folder/$sub_folder"
    local container_folder="/usr/src/app/$sub_folder"

    echo "test content" > "$host_folder/test_file.txt"

    if ! docker exec "$instance_name" test -f "$container_folder/test_file.txt"; then
      echo "FAIL: live_test_create_instance() :failed to mount folder $host_folder to $container_folder"
      cleanup
      exit 1
    fi

    local container_file_content
    container_file_content=$(docker exec "$instance_name" cat "$container_folder/test_file.txt")
    if [[ "$container_file_content" != "test content" ]]; then
      echo "FAIL: live_test_create_instance() :folder content does not match"
      echo "Expected:"
      echo "test content"
      echo "Actual:"
      echo "${container_file_content}"
      cleanup
      exit 1
    fi
  done

  # Cleanup
  cleanup

  echo "PASS: create_instance() tests passed"
}

test_main_mocked() {
  source ../bash_scripts/gateway-create.sh --source-only

  # Mock functions
  prompt_gateway_tag() {
    echo "test_tag"
  }

  prompt_instance_name() {
    echo "test_instance"
  }

  prompt_folder() {
    echo "/tmp/test_folder"
  }

  prompt_passphrase() {
    echo "test_passphrase"
  }

  check_available_port() {
    echo "$1"
  }

  ask() {
    echo "Y"
  }

  create_instance() {
    echo "create_instance called with: $*"
  }

  # Run main() and capture the output
  local result
  result=$(main)

  # Check if the create_instance function is called with the expected arguments
  local expected_output="create_instance called with: test_instance test_tag /tmp/test_folder 15888 8080 test_passphrase"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_main() :main() did not call create_instance with the expected arguments"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

   # Run main() in test mode and capture the output
  result=$(main "test_image_name")

  expected_output="create_instance called with: test_instance test_tag /tmp/test_folder 15888 8080 test_passphrase test_image_name"
  if [[ "$result" != *"$expected_output"* ]]; then
    echo "FAIL: test_main() :main() did not call create_instance with the expected arguments"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${result}"
    exit 1
  fi

 echo "PASS: test_main() :main() called create_instance with the expected arguments"
}

test_main_live() {
  trap cleanup EXIT

  source ../bash_scripts/gateway-create.sh --source-only

  # Prepare test parameters
  local test_instance_name="test-instance-3"
  local test_gateway_tag="latest"
  local test_folder=$(mktemp -d)
  local test_gateway_port=$(../bash_scripts/gateway-create.sh --test check_available_port "15888")
  local test_docs_port=$(../bash_scripts/gateway-create.sh --test check_available_port "8080")
  local test_passphrase="test_passphrase-3"
  local test_image_name="test-image-3"

  local temp_directory
  temp_directory=$(mktemp -d)
  mkdir -p "$temp_directory/certs" "$temp_directory/conf" "$temp_directory/logs"
  chmod +rw "$temp_directory/certs" "$temp_directory/conf" "$temp_directory/logs"

  build_test_image() {
    local build_context=$(mktemp -d)
    cat << EOF > $build_context/Dockerfile.test
FROM alpine:3.14
CMD ["sh", "-c", "echo 'Test image is running' && sleep 3600"]
EOF

    docker build -t "$test_image_name" -f $build_context/Dockerfile.test $build_context > /dev/null 2>&1
    rm -r $build_context
  }

  cleanup(){
  # Check if the container is running and remove it if it exists
    if docker ps -a --filter "name=$test_instance_name" --format "{{.Names}}" | grep -q "$test_instance_name"; then
      docker stop "$test_instance_name" > /dev/null 2>&1
      docker rm -f "$test_instance_name" > /dev/null 2>&1
    fi

    docker rmi "$test_image_name" > /dev/null 2>&1
    rm -rf "$folder"
    rm -rf "$temp_directory"
  }

  # Mock functions
  prompt_gateway_tag() {
    echo "$test_gateway_tag"
  }

  prompt_instance_name() {
    echo "$test_instance_name"
  }

  prompt_folder() {
    echo "$test_folder"
  }

  prompt_passphrase() {
    echo "$test_passphrase"
  }

  get_test_port() {
    local port_type=$1
    case "$port_type" in
      "15888")
        echo "$test_gateway_port"
        ;;
      "8080")
        echo "$test_docs_port"
        ;;
    esac
  }

  check_available_port() {
    local port_type=$1
    echo "$(get_test_port "$port_type")"
  }

  ask() {
    local message=$1
    local default_answer=$2

    # Return Y for confirmation prompts
    if [[ $message == *"Do you want to proceed"* ]]; then
      echo "Y"
    # Return the defined temporary directory for the directory prompt
    elif [[ $message == *"Enter the desired path"* ]]; then
      echo "$temp_directory"
    else
      echo "$default_answer"
    fi
  }

  build_test_image

  # Run main() and create the live test instance
  output=$(main "$test_image_name")

  # Give Docker some time to start the container
  sleep 5

  # Check if the folders were created
  for sub_folder in "${GW_SUB_FOLDERS[@]}"; do
    if [ ! -d "$temp_directory/$sub_folder" ]; then
      echo "FAIL: main() :$sub_folder not created inside the specified directory"
      cleanup
      exit 1
    fi
  done

  # Check if the container is running
  if ! docker ps --filter "name=$test_instance_name" --format "{{.Names}}" | grep -q "$test_instance_name"; then
    echo "FAIL: live_test_main() :instance is not running"
    cleanup
    exit 1
  fi

  # Check if the container logs contain the expected message
  local expected_output="Test image is running"
  local container_logs=$(docker logs "$test_instance_name")
  if [[ "$container_logs" != *"$expected_output"* ]]; then
    echo "FAIL: live_test_main() :container logs do not match expected output"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "${container_logs}"
    cleanup
    exit 1
  fi

  # Check if the folders are mounted correctly
  for sub_folder in "${GW_SUB_FOLDERS[@]}"; do
    local host_folder="$test_folder/$sub_folder"
    local container_folder="/usr/src/app/$sub_folder"

    echo "test content" > "$host_folder/test_file.txt"

    if ! docker exec "$test_instance_name" test -f "$container_folder/test_file.txt"; then
      echo "FAIL: live_test_main() :failed to mount folder $host_folder to $container_folder"
      cleanup
      exit 1
    fi

    local container_file_content
    container_file_content=$(docker exec "$test_instance_name" cat "$container_folder/test_file.txt")
    if [[ "$container_file_content" != "test content" ]]; then
      echo "FAIL: live_test_main() :folder content does not match"
      echo "Expected:"
      echo "test content"
      echo "Actual:"
      echo "${container_file_content}"
      cleanup
      exit 1
    fi
  done

  # Cleanup
  cleanup

  echo "PASS: live_test_main() tests passed"
  trap - EXIT
}

# Run tests
test_prompt_gateway_tag
test_prompt_folder
test_prompt_instance_name
test_prompt_passphrase
test_prompt_existing_certs_path
test_check_available_port
test_check_available_port_mocked_netstat
test_create_instance_mocked
test_create_instance
test_main_mocked
test_main_live

run_test_cases_gateway_create() {
  echo "Running test cases for hummingbot-start.sh..."

  test_prompt_gateway_tag
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_prompt_gateway_tag"
    exit 1
  fi

  test_prompt_folder
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_prompt_folder"
    exit 1
  fi

  test_prompt_instance_name
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_prompt_instance_name"
    exit 1
  fi

  test_prompt_passphrase
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_prompt_passphrase"
    exit 1
  fi

  test_prompt_existing_certs_path
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_prompt_existing_certs_path"
    exit 1
  fi

  test_check_available_port
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_check_available_port"
    exit 1
  fi

  test_check_available_port_mocked_netstat
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_check_available_port_mocked_netstat"
    exit 1
  fi

  test_create_instance_mocked
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_create_instance_mocked"
    exit 1
  fi

  test_create_instance
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_create_instance"
    exit 1
  fi

  test_main_mocked
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_main_mocked"
    exit 1
  fi

  test_main_live
  if [[ $? -ne 0 ]]; then
    echo "FAIL: test_main_live"
    exit 1
  fi

  echo "PASS: all test cases for hummingbot-start.sh"
}

echo
echo "All tests passed."
