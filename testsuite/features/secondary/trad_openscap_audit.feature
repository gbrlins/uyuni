# Copyright (c) 2015-2020 SUSE LLC
# Licensed under the terms of the MIT license.

Feature: openSCAP audit of traditional client
  In order to audit a traditional client
  As an authorized user
  I want to run an openSCAP scan on it

  Scenario: Schedule an audit job using the SUSE profile
    Given I am on the Systems overview page of this "sle_client"
    When I follow "Audit" in the content area
    And I follow "Schedule" in the content area
    And I enter "--profile Default" as "params"
    And I enter "/usr/share/openscap/scap-yast2sec-xccdf.xml" as "path"
    And I click on "Schedule"
    And I run "rhn_check -vvv" on "sle_client"
    Then I should see a "XCCDF scan has been scheduled" text

  Scenario: Check results of the audit job SUSE profile
    Given I am on the Systems overview page of this "sle_client"
    When I follow "Audit" in the content area
    And I follow first "xccdf_org.open-scap_testresult_Default"
    Then I should see a "Details of XCCDF Scan" text
    And I should see a "Default" text
    And I should see a "XCCDF Rule Results" text
    When I enter "pass" as the filtered XCCDF result type
    And I click on the filter button
    Then I should see a "rule-pwd-warnage" link

  Scenario: Cleanup: remove audit scans retention period from traditional client
    Given I am on the Organizations page
    When I follow "SUSE Test" in the content area
    And I follow "Configuration" in the content area
    And I enter "0" as "scap_retention_period"
    And I click on "Update Organization"
    Then I should see a "Organization SUSE Test was successfully updated." text

  Scenario: Cleanup: delete audit results from traditional client
    Given I am on the Systems overview page of this "sle_client"
    When I follow "Audit" in the content area
    And I follow "List Scans" in the content area
    And I click on "Select All"
    And I click on "Remove Selected Scans"
    And I click on "Confirm"
    Then I should see a "deleted. 0 SCAP Scan(s) retained" text

  Scenario: Cleanup: restore audit scans retention period on traditional client
    Given I am on the Organizations page
    When I follow "SUSE Test" in the content area
    And I follow "Configuration" in the content area
    And I enter "90" as "scap_retention_period"
    And I click on "Update Organization"
    Then I should see a "Organization SUSE Test was successfully updated." text
