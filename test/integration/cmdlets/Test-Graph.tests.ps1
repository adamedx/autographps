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

if ( ! ( & $psscriptroot/../../IsIntegrationTestRun.ps1 ) ) {
    return
}

Describe "The Test-Graph command executing unmocked" {

    Set-StrictMode -Version 2

    Context "when invoked for simple use cases" {

        It "should succeed when given no parameters" {
            { Test-Graph | out-null } | Should Not Throw
        }

        It "should succeed when given a cloud parameter" {
            { Test-Graph -cloud Public | out-null } | Should Not Throw
            { Test-Graph -cloud ChinaCloud | out-null } | Should Not Throw
            { Test-Graph -cloud USGovernmentCloud | out-null } | Should Not Throw
        }

        It "should succeed when given a custom graph URI parameter" {
            { Test-Graph -endpointuri 'https://graph.microsoft.com' | out-null } | Should Not Throw
        }

        It "should succeed when given a verbose parameter" {
            { Test-Graph -verbose *> $null } | Should Not Throw
        }

        It "should return a result with expected members" {
            $testResult = Test-Graph
            $testResult.NonfatalStatus | Should Not Be 0
            [Math]::Abs( ( [DateTimeOffset]::now - $testResult.ServerTimestamp ).Ticks ) | Should BeLessThan 6000000000 # 10 minutes
            ($testResult.ClientRequestTimestamp.GetType()) | Should BeExactly ([DateTimeOffset])
            ($testResult.ClientResponseTimestamp.GetType()) | Should BeExactly ([DateTimeOffset])
            { [guid] $testResult.RequestId } | Should Not Throw
            $testResult.ClientElapsedTime | Should BeLessThan ([TimeSpan]::new(0,2,0))
            $testResult.Slice | Should Not Be NullorEmpty
            $testResult.Ring | Should Not Be NullOrEmpty
            $testResult.ScaleUnit | Should Not Be NullOrEmpty
            $testResult.TestUri | Should Be 'https://graph.microsoft.com/v1.0/$metadata'
            $testResult.DataCenter | Should Not Be NullOrEmpty
        }
    }
}
