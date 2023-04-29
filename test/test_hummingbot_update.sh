#!/bin/bash

source $(dirname "$0")/../bash_scripts/folder-structure.sh
source $(dirname "$0")/../bash_scripts/hummingbot-common.sh

# Test implementation

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

test_prompt_folder() {
  # Test default folders
  local instances=("instance1" "instance2" "hummingbot-instance")
  local expected_folders=("$PWD/instance1_files" "$PWD/instance2_files" "$PWD/hummingbot_files")
  local folders=$(echo "" | ../bash_scripts/hummingbot-update.sh --test prompt_folder "${instances[@]}")
  if [ "$folders" != "${expected_folders[*]}" ]; then
    echo "FAIL: prompt_folder(): Default folders not set correctly"
    echo "Expected: ${expected_folders[*]}"
    echo "Actual:   ${folders[*]}"
    exit 1
  fi

  # Test custom folders
  local instances=("instance1" "instance2" "hummingbot-instance")
  local folder_inputs=("custom1\ncustom2\n/absolute/path/to/custom3")
  local expected_folders=("$PWD/custom1" "$PWD/custom2" "/absolute/path/to/custom3")
  local folders=$(echo -e "${folder_inputs[*]}\n" | ../bash_scripts/hummingbot-update.sh --test prompt_folder "${instances[@]}")
  if [ "$folders" != "${expected_folders[*]}" ]; then
    echo "FAIL: prompt_folder(): Custom folders not set correctly"
    echo "Expected: ${expected_folders[*]}"
    echo "Actual:   ${folders[*]}"
    exit 1
  fi

  echo "PASS: prompt_folder()"
}

test_list_dir() {
  # Create temporary directory and some folders
  local temp_dir=$(mktemp -d)
  mkdir "$temp_dir/folder1" "$temp_dir/folder2"

  # Test list_dir with default argument
  local expected_output=$(printf "\n   List of folders in your directory:\n\n   📁  folder1\n   📁  folder2")
  local actual_output=$(../bash_scripts/hummingbot-update.sh --test list_dir "$temp_dir")
  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: list_dir(): incorrect output for default argument"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Test list_dir with specific directory
  expected_output=$(printf "\n   List of folders in your directory:\n")
  actual_output=$(../bash_scripts/hummingbot-update.sh --test list_dir "$temp_dir/folder1")
  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: list_dir(): incorrect output for specific directory"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Cleanup
  rm -r "$temp_dir"
  echo "PASS: list_dir()"
}

test_list_instances_mocked_docker() {
  # Define the mock docker command
  function docker() {
    case "$1" in
      ps)
        # Return a list of containers with the given ancestor image
        shift
        if [ "$1" == "-a" ] && [ "$2" == "--filter" ] && [ "$3" == "ancestor=hummingbot/hummingbot:1.1.0" ]; then
          echo "CONTAINER ID        IMAGE                      COMMAND             CREATED             STATUS                     PORTS                    NAMES
c2457b28d74d        hummingbot/hummingbot:1.1.0   \"/bin/sh -c ./star   2 hours ago         Exited (0) 12 minutes ago                            instance1
f7b1f05811e6        hummingbot/hummingbot:1.1.0   \"/bin/sh -c ./star   3 hours ago         Up 3 hours                 0.0.0.0:5000->5000/tcp   instance2"
        fi
        ;;
      *)
        # Call the actual docker command for anything else
        command docker "$@"
        ;;
    esac
  }

  # Source the script to modify the function
  source ../bash_scripts/hummingbot-update.sh --source-only

  # Test list_instances
  local expected_output="
List of all docker containers using the \"1.1.0\" version:

CONTAINER ID        IMAGE                      COMMAND             CREATED             STATUS                     PORTS                    NAMES
c2457b28d74d        hummingbot/hummingbot:1.1.0   \"/bin/sh -c ./star   2 hours ago         Exited (0) 12 minutes ago                            instance1
f7b1f05811e6        hummingbot/hummingbot:1.1.0   \"/bin/sh -c ./star   3 hours ago         Up 3 hours                 0.0.0.0:5000->5000/tcp   instance2

⚠️  WARNING: This will attempt to update all instances. Any containers not in Exited () STATUS will cause the update to fail.

ℹ️  TIP: Connect to a running instance using \"./start.sh\" command and \"exit\" from inside Hummingbot.
ℹ️  TIP: You can also remove unused instances by running \"docker rm [NAME]\" in the terminal."
  local actual_output=$(list_instances "1.1.0")
  if [ "$actual_output" != "$expected_output" ]; then
    echo "FAIL: list_instances(): incorrect output"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Delete my_function
  unset docker

  echo "PASS: list_instances_mocked_docker()"
}

test_list_instances() {
  # Build a test Docker image
  local dockerfile=$(cat <<EOF
FROM alpine:3.14
CMD sleep 10
EOF
  )
  docker build -t hummingbot-test-image - <<<"$dockerfile" > /dev/null

  # Create a container from the test image
  local container_name="test-container-$(date +%s)"
  docker run -d --name "$container_name" hummingbot-test-image > /dev/null

  # Call the list_instances function
  local expected_output="
List of all docker containers using the \"latest\" version:

CONTAINER ID   IMAGE                   COMMAND                  CREATED                  STATUS                  PORTS     NAMES
"*"hummingbot-test-image"*"\"/bin/sh -c 'sleep 1…\""*"Up Less than a second"*"test-container-"*"

⚠️  WARNING: This will attempt to update all instances. Any containers not in Exited () STATUS will cause the update to fail.

ℹ️  TIP: Connect to a running instance using \"./start.sh\" command and \"exit\" from inside Hummingbot.
ℹ️  TIP: You can also remove unused instances by running \"docker rm [NAME]\" in the terminal."
  local actual_output=$(../bash_scripts/hummingbot-update.sh --test list_instances latest hummingbot-test-image)

  # Check for expected output
  if [[ "$actual_output" =~ *"$expected_output"* ]]; then
    echo "FAIL: list_instances(): incorrect output"
    echo "Expected: $eo_0 ... $eo_1 ... $eo_2 ... $eo_3"
    echo "Actual: $actual_output"
    docker rm -f "$container_name" >/dev/null
    docker rmi -f hummingbot-test-image >/dev/null
    exit 1
  fi

  # Cleanup
  docker rm -f "$container_name" >/dev/null
  docker rmi hummingbot-test-image >/dev/null
  echo "PASS: list_instances()"
}

# Test the confirm_update function
test_confirm_update() {
  # Input instances and folders
  local instances=("instance-1" "instance-2" "instance-3")
  local folders=("folder-1" "folder-2" "folder-3")
  local combined_args=("${instances[@]}" "${folders[@]}")

  # Call the confirm_update function and store the output
  local actual_output
  actual_output=$(../bash_scripts/hummingbot-update.sh --test confirm_update "${combined_args[@]}")

  # Define the expected output
  local expected_output="\
ℹ️  Confirm below if the instances and their folders are correct:

                      INSTANCE               FOLDER
                    instance-1  ---------->    folder-1
                    instance-2  ---------->    folder-2
                    instance-3  ---------->    folder-3"

  # Check for expected output
  if [[ "$actual_output" != *"$expected_output"* ]]; then
    echo "FAIL: confirm_update(): incorrect output"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi
  echo "PASS: confirm_update()"
}

# Test confirm_update function with an uneven number of arguments
test_confirm_update_error() {
  local uneven_args=("instance-1" "folder-1" "instance-2" "folder-2" "instance-3")

  local expected_error="❌  The number of instances and folders must be equal. Please check your input."
  local actual_error=$(../bash_scripts/hummingbot-update.sh --test confirm_update "${uneven_args[@]}")

  if [[ "$actual_error" != "$expected_error" ]]; then
    echo "FAIL: confirm_update_error(): incorrect error message"
    echo "Expected: $expected_error"
    echo "Actual: $actual_error"
    exit 1
  fi

  echo "PASS: confirm_update_error()"
}

test_remove_docker_containers_mocked_docker() {
  source ../bash_scripts/hummingbot-update.sh --source-only

  # Define a mocked docker function
  function docker() {
    case "$1" in
      rm)
        echo "Mocked docker rm ${@:2}"
        ;;
      *)
        command docker "$@"
        ;;
    esac
  }

  # Call the remove_docker_containers function
  local instances=("test-instance-1" "test-instance-2" "test-instance-3")
  local actual_output
  actual_output=$(remove_docker_containers "${instances[@]}")

  # Define the expected output
  local expected_output="Removing docker containers first ...
        Mocked docker rm test-instance-1 test-instance-2 test-instance-3"

  # Check for expected output
  if [[ "$actual_output" =~ *"$expected_output"* ]]; then
    echo "FAIL: remove_docker_containers(): incorrect output"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Delete mocked docker function
  unset docker

  echo "PASS: remove_docker_containers() - mocked"
}

test_remove_docker_containers() {
  # Remove the test containers if they exist
  for container_name in "${container_names[@]}"; do
    if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
      docker rm -f "$container_name" >/dev/null 2>&1
    fi
  done

  # Create test containers
  local container_names=("test-container-1" "test-container-2" "test-container-3")
  for container_name in "${container_names[@]}"; do
    docker run --name "$container_name" -d alpine >/dev/null 2>&1
  done

  # Call the remove_docker_containers function
  ../bash_scripts/hummingbot-update.sh --test remove_docker_containers "${container_names[@]}" > /dev/null

  # Check that the containers no longer exist
  for container_name in "${container_names[@]}"; do
    if docker ps -a --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
      echo "FAIL: remove_docker_containers(): container still exists: $container_name"
      docker rm -f "${container_names[@]}" > /dev/null 2>&1
      exit 1
    fi
  done

  echo "PASS: remove_docker_containers() - live"
}

test_delete_docker_image_mocked_docker() {
  source ../bash_scripts/hummingbot-update.sh --source-only

  # Define a mocked docker function
  function docker() {
    case "$1" in
      image)
        echo "Mocked docker image rm $3"
        ;;
      *)
        command docker "$@"
        ;;
    esac
  }

  # Call the delete_docker_image function
  local image_name="hummingbot-test-image"
  local tag="latest"
  local actual_output
  actual_output=$(delete_docker_image "$image_name" "$tag")

  # Define the expected output
  local expected_output="Deleting old image ...
        Mocked docker image rm hummingbot-test-image:latest"

  # Check for expected output
  if [[ "$actual_output" =~ *"$expected_output"* ]]; then
    echo "FAIL: delete_docker_image(): incorrect output"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Delete mocked docker function
  unset docker

  echo "PASS: delete_docker_image()"
}

test_delete_docker_image() {
  # Define the image name and tag
  local image_name="alpine"
  local tag="latest"

  # Clean up existing containers and images
  docker rm -f test-container >/dev/null 2>&1
  docker image rm -f "$image_name:$tag" >/dev/null 2>&1

  # Pull the Alpine image and tag it with the specified name and tag
  docker pull alpine >/dev/null 2>&1
  docker tag alpine "$image_name:$tag" >/dev/null 2>&1

  if ! docker image inspect "$image_name:$tag" >/dev/null 2>&1; then
    echo "FAIL: delete_docker_image(): TEST failure: unable to pull and tag image"
    exit 1
  fi

  # Run a temporary container from the image
  docker run --name test-container -d "$image_name:$tag" sleep 10 >/dev/null 2>&1

  # Stop the container
  docker stop test-container >/dev/null 2>&1

  # Call the delete_docker_image function
  ../bash_scripts/hummingbot-update.sh --test delete_docker_image "$image_name" "$tag" > /dev/null

  # Check that the image no longer exists
  if docker image inspect "$image_name:$tag" >/dev/null 2>&1; then
    echo "FAIL: delete_docker_image(): image still exists"
    # Clean up after the test
    docker image rm -f "$image_name:$tag" >/dev/null 2>&1
    exit 1
  fi

  # Clean up after the test
  docker image rm -f "$image_name:$tag" >/dev/null 2>&1

  echo "PASS: delete_docker_image() - live"
}

test_create_docker_containers_mocked_docker() {
  source ../bash_scripts/hummingbot-update.sh --source-only

  # Mock the run_docker function
  function run_docker() {
    echo "Mocked run_docker with args: $@"
  }

  function v_string() {
    local instance=$1
    local f_string=("conf" "logs" "data" "pmm-scripts" "scripts" "certs" "conf/connectors" "conf/strategies")

    local v_string=""
    for f_string in "${f_string[@]}"; do
        v_string+=" -v $instance/${f_string}:/${f_string}"
    done

    echo "$v_string"
  }

  # Call the create_docker_containers function
  local image_name="hummingbot-test-image"
  local tag="latest"
  local instances=("test-instance-1" "test-instance-2" "test-instance-3")
  local folders=("test-folder-1" "test-folder-2" "test-folder-3")
  local combined_args=("$image_name" "$tag" "${instances[@]}" "${folders[@]}")
  local actual_output
  actual_output=$(create_docker_containers "${combined_args[@]}")

  # Define the expected output
  local expected_output="Re-creating docker containers with updated image ...
Mocked run_docker with args: test-instance-1 latest $(v_string test-folder-1) $image_name
Mocked run_docker with args: test-instance-2 latest $(v_string test-folder-2) $image_name
Mocked run_docker with args: test-instance-3 latest $(v_string test-folder-3) $image_name"

  # Check for expected output
  if [[ "$actual_output" =~ *"$expected_output"* ]]; then
    echo "FAIL: create_docker_containers(): incorrect output"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Delete mocked run_docker function
  unset docker

  echo "PASS: create_docker_containers()"
}

test_execute_docker_mocked_docker() {
  # Source the script to modify the function
  source ../bash_scripts/hummingbot-update.sh --source-only

  function remove_docker_containers() {
    echo "Mocked remove_docker_containers with args: $@"
  }
  function delete_docker_image() {
    echo "Mocked delete_docker_image with args: $@"
  }
  function create_docker_containers() {
    echo "Mocked create_docker_containers with args: $@"
  }
  function docker() {
    echo "Mocked run_docker with args: $@"
  }

  # Input image_name, tag, instances, and folders
  local image_name="hummingbot/hummingbot"
  local tag="1.1.0"
  local instances=("test-instance-1" "test-instance-2" "test-instance-3")
  local folders=("test-folder-1" "test-folder-2" "test-folder-3")
  local combined_args=("${instances[@]}" "${folders[@]}")

  expected_output="Mocked remove_docker_containers with args: hummingbot/hummingbot 1.1.0 test-instance-1 test-instance-2
Mocked delete_docker_image with args: hummingbot/hummingbot 1.1.0
Mocked create_docker_containers with args: hummingbot/hummingbot 1.1.0 test-instance-1 test-instance-2 test-instance-3 test-folder-1 test-folder-2 test-folder-3

Update complete! All running docker instances:

Mocked run_docker with args: ps

ℹ️  Run command \"./hummingbot-start.sh\" to connect to an instance."

  # Call the execute_docker function
  actual_output=$(execute_docker "$image_name" "$tag" "${combined_args[@]}")

  # Check for expected output
  if [[ "$actual_output" != "$expected_output" ]]; then
    echo "FAIL: execute_docker(): incorrect output"
    echo "Expected: $expected_output"
    echo "Actual: $actual_output"
    exit 1
  fi

  # Delete mocked run_docker function
  unset remove_docker_containers delete_docker_image create_docker_containers docker

  echo "PASS: execute_docker()"
}

# Test confirm_update function with an uneven number of arguments
test_execute_docker_error() {
  # Source the script to modify the function
  source ../bash_scripts/hummingbot-update.sh --source-only

  function remove_docker_containers() {
    echo "Mocked remove_docker_containers with args: $@"
  }
  function delete_docker_image() {
    echo "Mocked delete_docker_image with args: $@"
  }
  function create_docker_containers() {
    echo "Mocked create_docker_containers with args: $@"
  }
  function docker() {
    echo "Mocked run_docker with args: $@"
  }

  local uneven_args=("instance-1" "folder-1" "instance-2" "folder-2" "instance-3")

  local expected_error="❌  The number of instances and folders must be equal. Please check your input."
  local actual_error=$(execute_docker "image" "tag" "${uneven_args[@]}")

  if [[ "$actual_error" != "$expected_error" ]]; then
    echo "FAIL: execute_docker_error(): incorrect error message"
    echo "Expected: $expected_error"
    echo "Actual: $actual_error"
    exit 1
  fi

  echo "PASS: execute_docker error()"
}

test_execute_docker_live_docker() {
  # Create a test Docker image
  docker build -t hummingbot/hummingbot:test - <<-EOF
  FROM alpine:3.14
  CMD ["sh", "-c", "echo 'Test Image' && sleep 86400"]
EOF

  # Input image_name, tag, instances, and folders
  local image_name="hummingbot/hummingbot"
  local tag="test"
  local instances=("live-test-instance-1" "live-test-instance-2" "live-test-instance-3")
  local folders=("live-test-folder-1" "live-test-folder-2" "live-test-folder-3")
  local combined_args=("$image_name" "$tag" "${instances[@]}" "${folders[@]}")

  # Call the execute_docker function
  ../bash_scripts/hummingbot-update.sh --test execute_docker "${combined_args[@]}"

  # Check if the instances have been created
  for instance in "${instances[@]}"; do
    if ! docker ps -a --format "{{.Names}}" | grep -q "^$instance\$"; then
      echo "FAIL: execute_docker(): instance not created: $instance"
      docker rm -f "${instances[@]}" >/dev/null
      docker rmi -f "${image_name}:${tag}" >/dev/null
      exit 1
    fi
  done

  # Cleanup
  docker rm -f "${instances[@]}" >/dev/null
  docker rmi -f "${image_name}:${tag}" >/dev/null

  echo "PASS: execute_docker()"
}

# Test main() function
test_main_default_values_mock() {
  local tag="latest"
  local folder=$(mktemp -d)

  source ../bash_scripts/hummingbot-update.sh --source-only

  # Create a temporary file to store the captured output of the docker() function
  local docker_output_file=$(mktemp)

  # Overriding the ask() function to provide answers for main()
  ask() {
    case "$1" in
      *"Hummingbot version"*)
        echo "$tag"
        ;;
      *"Do you want to continue?"*)
        echo "Y"
        ;;
      *"Enter the destination folder"*)
        echo "$folder"
        ;;
      *"Proceed?"*)
        echo "Y"
        ;;
    esac
  }

  # Overriding the docker() function to provide different responses based on input arguments
  docker() {
    case "$1" in
      "ps")
        if [[ "$2" == "-a" && "$3" == "--filter" ]]; then
          # Simulate the response for `docker ps -a --filter ...`
          echo "instance1"
          echo "instance2"
          echo "Docker command called with: $@" >> "$docker_output_file"
        fi
        ;;
      "rm")
        # Simulate the response for `docker rm ...`
        echo "Docker command called with: $@" >> "$docker_output_file"
        ;;
      "image")
        if [[ "$2" == "rm" ]]; then
          # Simulate the response for `docker image rm ...`
          echo "Docker command called with: $@" >> "$docker_output_file"
        fi
        ;;
      "run")
        # Simulate the response for `docker run ...`
        echo "Docker command called with: $@" >> "$docker_output_file"
        ;;
    esac
  }

  # Simulate user inputs with default values and capture the output
  output=$(echo -e "\n\n\n" | main 2>&1)

  # Read the content of the temporary file containing the captured docker output
  docker_output=$(cat "$docker_output_file")

  # Verify that the instances are listed
  expected_output="List of all docker containers using the \"$tag\" version"
  if [[ ! "$output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with default values: list_instances \$TAG"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$output"
    exit 1
  fi

  # Verify that the instances are listed
  expected_output="Docker command called with: ps -a --filter ancestor=hummingbot/hummingbot:$tag"
  if [[ ! "$docker_output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with default values: list instances"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$docker_output"
    echo "$output"
    exit 1
  fi

  # Verify that the container is removed
  expected_output="Docker command called with: rm hummingbot/hummingbot"
  if [[ ! "$docker_output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with default values: delete container"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  # Verify that the image names are found
  expected_output="Docker command called with: ps -a --filter ancestor=hummingbot/hummingbot:$tag --format"
  if [[ ! "$docker_output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with default values: list images"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  # Verify that the image is removed
  expected_output="Docker command called with: image rm -f hummingbot/hummingbot:$tag"
  if [[ ! "$docker_output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with default values: remove image"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  # Verify that the image are re-created for instance1
  expected_docker_args="Docker command called with: run -it --log-opt max-size=10m "
  expected_docker_args+="--log-opt max-file=5 --name instance1 --network host"
  # There is a subtlety here: the order of the volume arguments is not consistent (extra space for v-string)
  expected_docker_args+="$(v_string $folder) hummingbot/hummingbot:$tag"
  if [[ ! "$docker_output" =~ .*"$expected_docker_args".* ]]; then
    echo "FAIL: main() with default values: Docker command not called as expected"
    echo "Expected:"
    echo "$expected_docker_args"
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  # Verify that the image are re-created for instance2
  expected_docker_args="Docker command called with: run -it --log-opt max-size=10m "
  expected_docker_args+="--log-opt max-file=5 --name instance2 --network host"
  # There is a subtlety here: the order of the volume arguments is not consistent (extra space for v-string)
  expected_docker_args+="$(v_string $folder) hummingbot/hummingbot:$tag"
  if [[ ! "$docker_output" =~ .*"$expected_docker_args".* ]]; then
    echo "FAIL: main() with default values: Docker command not called as expected"
    echo "Expected:"
    echo "$expected_docker_args"
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  # Clean up temporary file
  rm "$docker_output_file"
  rm -r "$folder"
  unset ask docker
  echo "PASS: main() with default values"
}

# Test main() function with aborting update
test_main_abort_update() {
  local tag="latest"
  local folder=$(mktemp -d)

  source ../bash_scripts/hummingbot-update.sh --source-only

  # Create a temporary file to store the captured output of the docker() function
  local docker_output_file=$(mktemp)

  # Overriding the ask() function to provide answers for main() that abort the update
  ask() {
    case "$1" in
      *"Hummingbot version"*)
        echo "$tag"
        ;;
      *"Do you want to continue?"*)
        echo "Y"
        ;;
      *"Proceed?"*)
        echo "n"
        ;;
    esac
  }

  # Simulate user inputs with aborting update and capture the output
  output=$(echo -e "\n\n\n" | main 2>&1)

  # Read the contents of the temporary file into docker_output
  docker_output=$(cat "$docker_output_file")

  # Perform assertions to verify the expected behavior when aborting update
  expected_output="Update aborted"
  if [[ ! "$output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with aborting update: Update not aborted as expected"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$output"
    exit 1
  fi

  # Perform assertions to verify the expected behavior when aborting update
  if [[ ! "$docker_output" == "" ]]; then
    echo "FAIL: main() with aborting update: Docker command ran"
    echo "Expected:"
    echo ""
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  docker_output=""
  unset ask docker
  echo "PASS: main() with aborting update"
}

# Test main() function with aborting update
test_main_abort_update_early() {
  local tag="latest"
  local folder=$(mktemp -d)

  source ../bash_scripts/hummingbot-update.sh --source-only

  # Create a temporary file to store the captured output of the docker() function
  local docker_output_file=$(mktemp)

  # Overriding the ask() function to provide answers for main() that abort the update
  ask() {
    case "$1" in
      *"Hummingbot version"*)
        echo "$tag"
        ;;
      *"Do you want to continue?"*)
        echo "n"
        ;;
      *"Proceed?"*)
        echo "n"
        ;;
    esac
  }

  # Simulate user inputs with aborting update and capture the output
  output=$(echo -e "\n\n\n" | main 2>&1)

  # Read the contents of the temporary file into docker_output
  docker_output=$(cat "$docker_output_file")

  # Perform assertions to verify the expected behavior when aborting update
  expected_output="Update aborted"
  if [[ ! "$output" =~ .*"$expected_output".* ]]; then
    echo "FAIL: main() with aborting update: Update not aborted as expected"
    echo "Expected:"
    echo "$expected_output"
    echo "Actual:"
    echo "$output"
    exit 1
  fi

  # Perform assertions to verify the expected behavior when aborting update
  if [[ ! "$docker_output" == "" ]]; then
    echo "FAIL: main() with aborting update: Docker command ran"
    echo "Expected:"
    echo ""
    echo "Actual:"
    echo "$docker_output"
    exit 1
  fi

  docker_output=""
  unset ask docker
  echo "PASS: main() with aborting update early"
}

# Run tests
test_ask
test_prompt_folder
test_list_dir
test_list_instances_mocked_docker
test_list_instances
test_confirm_update
test_confirm_update_error
test_remove_docker_containers_mocked_docker
test_remove_docker_containers
test_delete_docker_image_mocked_docker
test_delete_docker_image
test_create_docker_containers_mocked_docker
test_execute_docker_mocked_docker
test_execute_docker_error
test_main_default_values_mock
test_main_abort_update
test_main_abort_update_early

run_test_cases_hummingbot_update() {
  echo "Running test cases for ../bash_scripts/hummingbot-update.sh"

  test_ask
  if [ $? -ne 0 ]; then
    echo "FAIL: test_ask"
    exit 1
  fi

  test_prompt_folder
  if [ $? -ne 0 ]; then
    echo "FAIL: test_prompt_folder"
    exit 1
  fi

  test_list_dir
  if [ $? -ne 0 ]; then
    echo "FAIL: test_list_dir"
    exit 1
  fi

  test_list_instances_mocked_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_list_instances_mocked_docker"
    exit 1
  fi

  test_list_instances
  if [ $? -ne 0 ]; then
    echo "FAIL: test_list_instances"
    exit 1
  fi

  test_confirm_update
  if [ $? -ne 0 ]; then
    echo "FAIL: test_confirm_update"
    exit 1
  fi

  test_confirm_update_error
  if [ $? -ne 0 ]; then
    echo "FAIL: test_confirm_update_error"
    exit 1
  fi

  test_remove_docker_containers_mocked_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_remove_docker_containers_mocked_docker"
    exit 1
  fi

  test_delete_docker_image_mocked_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_delete_docker_image_mocked_docker"
    exit 1
  fi

  test_create_docker_containers_mocked_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_create_docker_containers_mocked_docker"
    exit 1
  fi

  test_execute_docker_mocked_docker
  if [ $? -ne 0 ]; then
    echo "FAIL: test_execute_docker_mocked_docker"
    exit 1
  fi

  test_execute_docker_error
  if [ $? -ne 0 ]; then
    echo "FAIL: test_execute_docker_error"
    exit 1
  fi

  test_main_default_values_mock
  if [ $? -ne 0 ]; then
    echo "FAIL: test_main_default_values_basic_mock"
    exit 1
  fi

  test_main_abort_update
  if [ $? -ne 0 ]; then
    echo "FAIL: test_main_abort_update"
    exit 1
  fi

  test_main_abort_update_early
  if [ $? -ne 0 ]; then
    echo "FAIL: test_main_abort_update_early"
    exit 1
  fi

  echo "All test cases for ../bash_scripts/hummingbot-update.sh passed"
}