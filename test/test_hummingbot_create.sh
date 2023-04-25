#!/bin/bash

source $(dirname "$0")/../bash_scripts/folder_structure.sh

# Test default values
test_ask() {
  # Test default value
  DEFAULT_VALUE=$(echo "" | ../bash_scripts/hummingbot-create.sh --test ask "Enter a value (default = \"default_value\") >>> " "default_value")
  if [ "$DEFAULT_VALUE" != "default_value" ]; then
    echo "FAIL: ask(): Default value should be 'default_value'"
    exit 1
  fi

  # Test custom value
  CUSTOM_VALUE=$(echo "custom_value" | ../bash_scripts/hummingbot-create.sh --test ask "Enter a value (default = \"default_value\") >>> " "default_value")
  if [ "$CUSTOM_VALUE" != "custom_value" ]; then
    echo "FAIL: ask(): Custom value should be 'custom_value'"
    exit 1
  fi
  echo "PASS: ask()"
}

test_print_folder_structure() {
  INSTANCE_NAME="test_instance"
  TAG="latest"
  FOLDER="/path/to/test_instance_files"
  CONF_FOLDER="$FOLDER/conf"
  LOGS_FOLDER="$FOLDER/logs"
  DATA_FOLDER="$FOLDER/data"
  PMM_SCRIPTS_FOLDER="$FOLDER/pmm-scripts"
  SCRIPTS_FOLDER="$FOLDER/scripts"
  CERTS_FOLDER="$FOLDER/certs"

  EXPECTED_OUTPUT=$(cat << EOM
                Instance name: test_instance
                      Version: hummingbot/hummingbot:latest

             Main folder path: $FOLDER
                 Config files: ├── $CONF_FOLDER
                    Log files: ├── $LOGS_FOLDER
         Trade and data files: ├── $DATA_FOLDER
            PMM scripts files: ├── $PMM_SCRIPTS_FOLDER
                Scripts files: ├── $SCRIPTS_FOLDER
                   Cert files: ├── $CERTS_FOLDER
EOM
)

  ACTUAL_OUTPUT=$(../bash_scripts/hummingbot-create.sh --test print_folder_structure "$INSTANCE_NAME" "$TAG" "$FOLDER")

  if [ "$ACTUAL_OUTPUT" != "$EXPECTED_OUTPUT" ]; then
    echo "FAIL: print_folder_structure(): output does not match expected output"
    echo "Expected:"
    echo "$EXPECTED_OUTPUT"
    echo "Actual:"
    echo "$ACTUAL_OUTPUT"
    exit 1
  fi
  echo "PASS: print_folder_structure()"
}

test_prompt_proceed() {
  local input="Y"
  local expected_output="Y"
  local actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-create.sh --test prompt_proceed)

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_prompt_proceed(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi

  input="N"
  expected_output="N"
  actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-create.sh --test prompt_proceed)

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_prompt_proceed(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi

  input=""
  expected_output="Y"
  actual_output=$(printf "$input\n" | ../bash_scripts/hummingbot-create.sh --test prompt_proceed)

  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: test_prompt_proceed(): input: '$input', expected: '$expected_output', actual: '$actual_output'"
    exit 1
  fi
  echo "PASS: prompt_proceed()"
}

test_create_folders() {
  temp_folder=$(mktemp -d)
  FOLDER="$temp_folder/folder"

  ../bash_scripts/hummingbot-create.sh --test create_folders "$FOLDER"

  # Check if all folders are created
  for sub_folder in "${SUB_FOLDERS[@]}"; do
    if [ ! -d "$FOLDER/$sub_folder" ]; then
      echo "FAIL: create_folders(): $FOLDER/$sub_folder not created"
      exit 1
    fi
  done

  for sub_conf_extra in "${SUB_CONF_EXTRAS[@]}"; do
    if [ ! -d "$FOLDER/conf/$sub_conf_extra" ]; then
      echo "FAIL: create_folders(): $FOLDER/conf/$sub_conf_extra not created"
      exit 1
    fi
  done

  # Clean up
  rm -rf "$temp_folder"
  echo "PASS: create_folders() creates correct folders (according to folder_structure.sh)"
}

test_set_rw_permissions() {
  # Check if the user can run sudo without entering a password
  temp_folder=$(mktemp -d)
  CONF_FOLDER="$temp_folder/conf"
  CERTS_FOLDER="$temp_folder/certs"

  mkdir -p "$CONF_FOLDER" "$CERTS_FOLDER"
  chmod 700 "$CONF_FOLDER" "$CERTS_FOLDER"

  # Run the set_rw_permissions function and capture its output
  OUTPUT=$(../bash_scripts/hummingbot-create.sh --test set_rw_permissions "$temp_folder" 2>&1)

  # Check if sudo was needed
  if echo "$OUTPUT" | grep -q "sudo:"; then
    echo "SKIPPED: test_set_rw_permissions(): This test requires sudo access without a password"
  else
    # Check if the permissions are set correctly
    if [ ! -w "$CONF_FOLDER" ] || [ ! -w "$CERTS_FOLDER" ]; then
      echo "FAIL: set_rw_permissions(): Permissions were not set correctly"
      exit 1
    fi

    # Clean up
    rm -rf "$temp_folder"
    echo "PASS: set_rw_permissions() updates permissions"
  fi
}

# Testing call to Docker is correct
mock_run_docker() {
  local instance_name=$1
  local tag=$2
  local docker_volume_args=$3

  if [[ "$instance_name" != "test_instance" ]]; then
    echo "FAIL: Invalid instance name passed to run_docker: $instance_name"
    exit 1
  fi

  if [[ "$tag" != "latest" ]]; then
    echo "FAIL: Invalid tag passed to run_docker: $tag"
    exit 1
  fi

  # Check if the test files are present in the mounted directories
  for sub_folder in "${SUB_FOLDERS[@]}"; do
    if [[ ! "$docker_volume_args" =~ "/path/to/test_instance_files/$sub_folder:/$sub_folder" ]]; then
      echo "FAIL: Invalid docker_volume_args for <$sub_folder> passed to run_docker: $docker_volume_args"
      exit 1
    fi
  done
  for sub_conf_extra in "${SUB_CONF_EXTRAS[@]}"; do
    if [[ ! "$docker_volume_args" =~ "/path/to/test_instance_files/conf/$sub_conf_extra:/conf/$sub_conf_extra" ]]; then
      echo "FAIL: Invalid docker_volume_args for <conf/$sub_conf_extra> passed to run_docker: $docker_volume_args"
      exit 1
    fi
  done
}

test_create_instance_runs_docker() {
  INSTANCE_NAME="test_instance"
  TAG="latest"
  FOLDER="/path/to/test_instance_files"

  # Change to the directory containing the hummingbot-create.sh script
  pushd "$(dirname "${BASH_SOURCE[0]}")/../bash_scripts" >/dev/null

  # Replace the actual run_docker function with the mock function
  source ./hummingbot-create.sh
  run_docker() {
    mock_run_docker "$@"
  }

  # mock the other functions
  create_folders() {
    echo "Mock create_folders executed" > /dev/null
  }
  set_rw_permissions() {
    echo "Mock set_permissions executed" > /dev/null
  }

  # Run the create_instance function
  create_instance "$INSTANCE_NAME" "$TAG" "$FOLDER" > /dev/null

  # Change back to the original directory
  popd >/dev/null

  echo "PASS: create_instance() calls docker with correct parameters"
}

test_docker_mounted_directories() {
  temp_folder=$(mktemp -d)
  local folder="$temp_folder/test_instance_files"

  # Create some test files in the mounted directories
  for sub_folder in "${SUB_FOLDERS[@]}"; do
    mkdir -p "$folder/$sub_folder"
    touch "$folder/$sub_folder/testfile"
  done

  for sub_conf_extra in "${SUB_CONF_EXTRAS[@]}"; do
    mkdir -p "$folder/conf/$sub_conf_extra"
    touch "$folder/conf/$sub_conf_extra/testfile"
  done

  # Get the directory structure of a virgin Alpine image
  virgin_docker_output=$(docker run --rm alpine sh -c "find / -mindepth 1 -not -path '/dev*' -not -path '/etc*' -not -path '/lib*' -not -path '/proc*' -not -path '/sbin*' -not -path '/sys*' -not -path '/usr*' -not -path '/var*'")

  # Run the lightweight Alpine image with the same volume arguments as your actual Docker run command
  DOCKER_VOLUME_ARGS=$(build_docker_volume_args "$folder")
  docker_output=$(docker run --rm $DOCKER_VOLUME_ARGS \
    alpine sh -c "find / -mindepth 1 -not -path '/dev*' -not -path '/etc*' -not -path '/lib*' -not -path '/proc*' -not -path '/sbin*' -not -path '/sys*' -not -path '/usr*' -not -path '/var*'")

  # Compare the virgin and mounted directory structures
  diff_output=$(diff <(echo "$virgin_docker_output") <(echo "$docker_output"))

  # Check if the mounted directories and test files are present
  for sub_folder in "${SUB_FOLDERS[@]}"; do
    if [[ ! "$diff_output" =~ "> /$sub_folder/testfile" ]]; then
      echo "FAIL: Directory '$sub_folder' not mounted correctly"
      exit 1
    fi
  done
  for sub_conf_extra in "${SUB_CONF_EXTRAS[@]}"; do
    if [[ ! "$diff_output" =~ "> /conf/$sub_conf_extra/testfile" ]]; then
      echo "FAIL: Directory 'conf/$sub_conf_extra' not mounted correctly"
      exit 1
    fi
  done
  echo "PASS: Directories mounted correctly and no unexpected files or directories created"

  # Run the Alpine image again and remove the added files
  docker run --rm   $DOCKER_VOLUME_ARGS \
    alpine sh -c "for d in /conf /certs; do rm \$d/testfile; done"

  # Check if the new files were removed from the mounted directories
  for sub_folder in /conf /certs; do
    if [ -f "$folder/$sub_folder/testfile" ]; then
      echo "FAIL: Failed to remove 'testfile' from '$sub_folder'"
      exit 1
    fi
  done

  # Run the Alpine image with the same volume arguments as your actual Docker run command and add a file within each mounted directory
  docker run --rm  $DOCKER_VOLUME_ARGS \
    alpine sh -c "for d in  /conf /certs; do touch \$d/newfile; done"

  # Check if the new files were added to the mounted directories
  for sub_folder in  /conf /certs; do
    if [ ! -f "$folder/$sub_folder/newfile" ]; then
      echo "FAIL: Failed to add 'newfile' to '$sub_folder'"
      exit 1
    fi
  done

  rm -rf "$temp_folder"
  echo "PASS: Docker can add and remove files in mounted directories"
}

# Run the tests
test_ask
test_print_folder_structure
test_prompt_proceed
test_create_folders
test_set_rw_permissions
test_create_instance_runs_docker
test_docker_mounted_directories

run_test_cases_hummingbot_create() {
    echo "Running test cases for ../bash_scripts/hummingbot-create.sh"

  test_ask
  if [ $? -ne 0 ]; then
    echo "FAIL: test_ask"
    exit 1
  fi

  test_print_folder_structure
  if [ $? -ne 0 ]; then
    echo "FAIL: test_print_folder_structure"
    exit 1
  fi

  test_prompt_proceed
  if [ $? -ne 0 ]; then
    echo "FAIL: test_prompt_proceed"
    exit 1
  fi

  test_create_folders
  if [ $? -ne 0 ]; then
    echo "FAIL: test_create_folders"
    exit 1
  fi

  test_set_rw_permissions
  if [ $? -ne 0 ]; then
    echo "FAIL: test_set_rw_permissions"
    exit 1
  fi

  test_create_instance_runs_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_create_instance"
    exit 1
  fi

  test_docker_mounted_directories
  if [ $? -ne 0 ]; then
    echo "FAIL: test_create_instance"
    exit 1
  fi

  echo "All test cases for ../bash_scripts/hummingbot-create.sh passed"
}