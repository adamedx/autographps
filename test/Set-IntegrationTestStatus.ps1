# Copyright 2022, Adam Edwards
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

[cmdletbinding()]
param(
    [ValidateSet('Enabled', 'Disabled')]
    $Status = 'Enabled',

    [Switch] $UpdateTestRunId,

    $testScriptRoot = $null
)

if ( $UpdateTestRunId.IsPresent ) {
    $testStatus = & $psscriptroot/Get-IntegrationTestStatus.ps1
    $testId = new-guid
    Set-Content -Path $testStatus.TestRunIdPathName -Value $testId.Guid.ToString()
    $global:__IntegrationTest_TestId = $testId.Guid.ToString()
} elseif ( $Status -eq 'Enabled' ) {
    $global:__IntegrationTestRoot = if ( $testScriptRoot ) {
        if ( ! ( test-path $testScriptRoot ) ) {
            throw "The specified path '$testScriptRoot' is not valid or does not exist"
        }
        $testScriptRoot
    } else {
        $psscriptRoot
    }
} else {
    $testVariable = Get-Variable __IntegrationTestRoot -ErrorAction Ignore

    if ( $testVariable ) {
        $testVariable | Set-Variable -Value $null
    }

    if ( $__IntegrationTestRoot ) {
        throw 'Failed to disable integration testing status by setting $__IntegrationTestRoot variable to $null -- the variable may be defined at multiple scopes. Remove the variable at all scopes or set it to null in all scopes and retry the command.'
    }
}

