# File: features/gateway_copy_certs.feature

Feature: Test gateway-copy-certs.sh script

  Scenario: Test script with valid inputs
    Given the script is run with valid inputs
    Then the script should complete successfully

  Scenario: Test script with invalid Hummingbot certs folder
    Given the script is run with an invalid Hummingbot certs folder
    Then the script should display an error and exit
