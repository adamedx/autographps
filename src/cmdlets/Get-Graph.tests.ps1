# Copyright (c) Adam Edwards
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


Describe 'The Get-Graph cmdlet' {
    BeforeEach {
        Get-Graph | Remove-Graph -warningaction silentlycontinue 3>&1 | out-null
    }

    AfterEach {
        Get-Graph | Remove-Graph -warningaction silentlycontinue 3>&1 | out-null
    }

    Context 'When invoking the Get-Graph command' {
        It "Should successfully return the default if there is no other graph mounted" {
            Get-Graph | Select -expandproperty name | Should Be 'v1.0'
        }

        It "Should throw an exception if a the graph with the specified name does not exist" {
            { Get-Graph idontexist } | Should Throw
        }

        It "Should return a new graph if it is added" {
            $newGraph = new-graph NewGraph1

            $newGraph.Name | Should be NewGraph1

            Get-Graph $newGraph.Name | select -expandproperty Name | Should be $newGraph.Name
        }

        It "Should throw an exception if a graph is removed by name and immediately specified by name" {
            $newGraph = new-graph NewGraphRemoved

            { Get-Graph $newGraph.Name } | Should Not Throw

            Remove-Graph $newGraph.Name

            { Get-Graph $newGraph.Name } | Should Throw
        }
    }
}
