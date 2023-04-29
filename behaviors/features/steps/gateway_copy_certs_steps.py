import shutil
import tempfile

from behave import given, when, then
import os
import subprocess
from pathlib import Path
from behave import given, when, then
import pexpect

script = Path(__file__).parent.parent.parent.parent / "bash_scripts" / "gateway-copy-certs.sh"


@given('the script is run with valid inputs')
def step_run_script_with_valid_inputs(context):
    context.script = script
    context.instance_name = "gateway"

    context.tempdir = tempfile.mkdtemp()
    context.hummingbot_certs_folder = tempfile.mkdtemp(dir=context.tempdir)
    context.gateway_certs_folder = tempfile.mkdtemp(dir=context.tempdir)

    context.certs_from_path = context.hummingbot_certs_folder
    context.certs_to_path = context.gateway_certs_folder


@given('the script is run with an invalid Hummingbot certs folder')
def step_run_script_with_invalid_hummingbot_certs_folder(context):
    context.script = script
    context.instance_name = "gateway"
    context.certs_from_path = "/path/to/your/nonexistent_hummingbot_certs_folder"


@given('the script is run with an invalid Gateway certs folder')
def step_run_script_with_invalid_hummingbot_certs_folder(context):
    context.script = script
    context.instance_name = "gateway"
    context.certs_to_path = "/path/to/your/nonexistent_hummingbot_certs_folder"


@given('the script is run with an empty Hummingbot certs folder')
def step_run_script_with_invalid_hummingbot_certs_folder(context):
    context.script = script
    context.instance_name = "gateway"


@given('the script is run and the user cancels the operation')
def step_run_script_and_user_cancels(context):
    context.script = script
    context.instance_name = "gateway"
    context.hummingbot_certs_file = tempfile.mkdtemp(dir=context.hummingbot_certs_folder)


@then('the script should display an error and exit')
def step_script_displays_error_and_exits(context):
    child = context.child
    child.expect("Error: (.*) is not a valid directory")
    error_message = child.match.group(1)
    assert error_message == context.invalid_certs_from_path

    try:
        child.expect("Enter path to the Gateway certs folder", timeout=1)
        assert False, "The script should have exited, but it did not."
    except pexpect.TIMEOUT:
        # If the script does not display the "Enter path to the Gateway certs folder" prompt
        # within the specified timeout, it means the script has exited as expected.
        pass
    assert child.before.decode().find("Error:") != -1


@then('the script should complete successfully')
def step_script_completes_successfully(context):
    child = pexpect.spawn(str(context.script))
    child.expect("Enter Gateway container name")
    child.sendline(context.instance_name)

    child.expect("Enter path to the Hummingbot certs folder")
    child.sendline(context.certs_from_path)

    child.expect("Enter path to the Gateway certs folder")
    child.sendline(context.certs_to_path)

    child.expect("Do you want to proceed?")
    child.sendline("Y")

    child.expect(pexpect.EOF)
    assert child.before.decode().find("Files successfully copied") != -1

    # Cleanup temporary directories
    shutil.rmtree(context.tempdir)
