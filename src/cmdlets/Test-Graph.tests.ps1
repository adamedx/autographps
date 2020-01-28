# Copyright 2020, Adam Edwards
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

Describe "The Test-Graph cmdlet" {

    $graphPing200Response = get-content -encoding utf8 -path "$psscriptroot\..\TestAssets\GraphPing200.json"


    Add-MockInScriptClassScope RESTRequest Invoke-WebRequest -MockContext $graphPing200Response {
        $result = $MockContext | convertfrom-json
        $result.headers = @{}
        $result
    }

    Context "when receiving a successful response from Graph" {
        It "should succeed when given no parameters" {
            { Test-Graph | out-null } | Should Not Throw
        }

        It "should succeed when given a cloud parameter" {
            { Test-Graph -cloud Public | out-null } | Should Not Throw
            { Test-Graph -cloud ChinaCloud | out-null } | Should Not Throw
            { Test-Graph -cloud GermanyCloud | out-null } | Should Not Throw
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
            ($testResult.TimeLocal).gettype() | Should BeExactly ([DateTime])
            ($testResult.TimeUtc).gettype() | Should BeExactly ([DateTime])
            ($testResult.Build).gettype() | Should BeExactly ([string])
            ($testResult.Slice).gettype() | Should BeExactly ([string])
            ($testResult.Ring).gettype() | Should BeExactly ([string])
            ($testResult.ScaleUnit).gettype() | Should BeExactly ([string])
            ($testResult.Host).gettype() | Should BeExactly ([string])
            ($testResult.ADSiteName).gettype() | Should BeExactly ([string])
        }

        It "should return a result with a TimeUtc member with a property of [DateTimeKind]::Utc" {
            $testResult = Test-Graph
            $testResult.TimeUtc.kind | Should BeExactly ([DateTimeKind]::Utc)
        }
    }
}
