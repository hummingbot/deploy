Feature: Hummingbot instance creation

  Scenario: Create a new Hummingbot instance with default values
    Given a new Hummingbot instance with default values
    When I create a new instance with default values
    Then I should see the required subfolders created with default values

  Scenario: Create a new Hummingbot instance with custom instance name and version
    Given a new Hummingbot instance name "custom_instance" and version "development"
    When I create a new instance with folder "custom_folder"
    Then I should see the required subfolders created in "custom_folder"

  Scenario: Abort creating a new Hummingbot instance
    Given a new Hummingbot instance name "abort_instance" and version "latest"
    When I choose not to proceed with creating a new instance
    Then the instance should not be created