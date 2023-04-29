import subprocess

import pexpect
from behave import given, when, then
import os
import shutil
from pexpect import EOF, TIMEOUT


@given('a new Hummingbot instance with default values')
def step_default_values(context):
    context.instance_name = "hummingbot"
    context.tag = "latest"


@when('I create a new instance with default values')
def step_create_instance_with_defaults(context):
    folder = "tmp_test_folder_default"
    context.folder = folder
    cmd = f"../bash_scripts/hummingbot-create.sh --test create_instance {context.instance_name} {context.tag} {folder}"
    subprocess.run(cmd, shell=True, check=True)


@then('I should see the required subfolders created with default values')
def step_verify_subfolders_created_with_defaults(context):
    # Verify the folder structure using the same subfolders list in the script
    cmd = "bash -c 'source ../bash_scripts/folder-structure.sh; echo ${SUB_FOLDERS[*]}'"
    sub_folders_str = subprocess.check_output(cmd, shell=True, text=True).strip()
    sub_folders = sub_folders_str.split(' ')
    for sub_folder in sub_folders:
        assert os.path.isdir(f"{context.folder}/{sub_folder}"), f"{sub_folder} not found in {context.folder}"


@when('I choose not to proceed with creating a new instance')
def step_abort_instance_creation(context):
    # Simulate user input to abort the instance creation
    folder = "tmp_test_folder_abort"

    cmd = f"../bash_scripts/hummingbot-create.sh"
    child = pexpect.spawn(cmd)
    child.expect("Enter Hummingbot version you want to use")
    child.sendline(context.instance_name)
    child.expect("Enter a name for your new Hummingbot instance")
    child.sendline(context.tag)
    child.expect("Enter a folder name where your Hummingbot files will be saved")
    child.sendline(folder)
    child.expect("Do you want to proceed")
    child.sendline("N")
    child.wait()

    context.folder = folder


@then('the instance should not be created')
def step_verify_instance_not_created(context):
    # Check that the folder was not created
    assert not os.path.exists(context.folder), f"{context.folder} should not have been created"


@given('a new Hummingbot instance name "{instance_name}" and version "{tag}"')
def step_given_instance_name_and_version(context, instance_name, tag):
    context.instance_name = instance_name
    context.tag = tag


@when('I create a new instance with folder "{folder}"')
def step_create_new_instance_with_folder(context, folder):
    context.instance_folder = folder
    cmd = "bash ../bash_scripts/hummingbot-create.sh"
    child = pexpect.spawn(cmd, timeout=10)

    # Answer the version prompt with "latest"
    child.expect("Enter Hummingbot version you want to use", timeout=10)
    child.sendline("latest")

    # Answer the instance name prompt with "test_instance"
    child.expect("Enter a name for your new Hummingbot instance", timeout=10)
    child.sendline("test_instance")

    # Answer the folder prompt with the folder variable
    child.expect("Enter a folder name where your Hummingbot files will be saved", timeout=10)
    child.sendline(folder)

    # Confirm the instance creation with "Y"
    child.expect("Do you want to proceed?", timeout=10)
    child.sendline("Y")

    try:
        child.expect(EOF, timeout=10)
    except TIMEOUT:
        raise AssertionError("The script did not finish as expected.")


@then('I should see the required subfolders created in "{folder}"')
def step_verify_subfolders_created(context, folder):
    # Import SUB_FOLDERS variable from folder_structure.sh
    cmd = "bash -c 'source ../bash_scripts/folder-structure.sh; echo ${SUB_FOLDERS[*]}'"
    sub_folders_str = subprocess.check_output(cmd, shell=True, text=True).strip()
    sub_folders = sub_folders_str.split(' ')

    # Check if the expected subfolders exist in the specified folder
    for sub_folder in sub_folders:
        assert os.path.exists(os.path.join(folder, sub_folder)), f"{sub_folder} not found in {folder}"

    if os.path.exists(folder):
        shutil.rmtree(folder)
