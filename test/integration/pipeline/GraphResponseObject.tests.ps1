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

Describe "The GraphResponseObject type" {

    Set-StrictMode -Version 2

    Context "When the pipeline processes a GraphResponseObject type" {
        BeforeAll {
            Connect-GraphApi -Connection $global:__IntegrationTestGraphConnection | out-null
            $thisTestInstanceId = New-Guid | select -expandproperty guid

            $appTags = $global:__IntegrationTestInfo.TestRunId, $thisTestInstanceId, '__IntegrationTest__'
        }

        It "should successfully pipe a GraphResponseObjet from New-GraphApplication to Remove-GraphItem" {
            $testAppName = 'SimpleTestAppToDelete' + $thisTestInstanceId
            $newApp = New-GraphApplication -Name $testAppName -Tags $appTags
            $newApp.DisplayName | Should Be $testAppName
            Get-GraphApplication $newApp.AppId | Should Not Be $null
            { $newApp | Remove-GraphItem } | Should Not Throw
            Get-GraphApplication $newApp.AppId -erroraction ignore | Should Be $null
        }

        AfterAll {
            Get-GraphApplication -Tags $thisTestInstanceId | Remove-GraphItem
        }
    }
}
