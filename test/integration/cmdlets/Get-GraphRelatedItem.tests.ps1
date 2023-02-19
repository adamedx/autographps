# Copyright 2023, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if ( ! ( & $psscriptroot/../../IsIntegrationTestRun.ps1 ) ) {
    return
}

Describe "The Get-GraphRelatedItem command executing unmocked" {

    Set-StrictMode -Version 2
    $erroractionpreference = 'stop'

    Context "when invoked for simple use cases" {
        BeforeAll {
            $currentConnection = Connect-GraphApi -Connection $global:__IntegrationTestGraphConnection
            $thisApplicationId = $currentconnection.identity.app.appid
            $thisServicePrincipal = Get-GraphApplicationServicePrincipal $thisApplicationId

            $thisTestInstanceId = New-Guid | select -expandproperty guid

            $appTags = $global:__IntegrationTestInfo.TestRunId, $thisTestInstanceId, '__IntegrationTest__'
            $appPrefix = 'ggri-test-app'

            $apps = 0..4 | foreach {
                # Use SkipTenantRegistration to avoid registering a service principal.
                # Otherwise when we later enumerate owned objects we'll get both the app and the service principal.
                # For simplicity, we'd like to just have the app
                New-GraphApplication -Name "$appPrefix$($_)" -SkipTenantRegistration
            }
        }

        It "should successfully return owned objects created by this app when accessing the ownedObjects relationship of this app's service principal" {
            $ownedApps = Get-GraphRelatedItem /servicePrincipals/$($thisServicePrincipal.Id) -Relationship ownedObjects
            $testAppSubset = $ownedApps | where appId -in $apps.appId
            $testAppSubset | measure-object | select-object -expandproperty count | Should Be ( $apps | measure-object | select-object -expandproperty count )
            $testAppSubset | get-member -membertype noteproperty | measure-object | select-object -expandproperty count | Should BeGreaterThan 10
        }

        It "should successfully return owned objects created by this app with a subset of properties when accessing the ownedObjects relationship of this app's service principal using select to project only 3 properties" {
            $projectedProperties = 'id', 'displayName', 'appId'
            $expectedProperties = $projectedProperties + '@odata.type'

            $ownedApps = Get-GraphRelatedItem /servicePrincipals/$($thisServicePrincipal.Id) -Relationship ownedObjects -Select id, displayName, appId
            $testAppSubset = $ownedApps | where appId -in $apps.appId

            $testAppSubset | measure-object | select-object -expandproperty count | Should Be ( $apps | measure-object | select-object -expandproperty count )
            $testAppSubset | get-member -membertype noteproperty | select-object -expandproperty Name | compare-object $expectedProperties | Should Be $null
        }

        AfterAll {
            foreach ( $app in ( Get-GraphApplication -Tags $thisTestInstanceId ) ) {
                $app | Remove-GraphItem
            }
        }
    }
}
