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

set-strictmode -version 2

Describe 'The TypeSearcher class' {
    Context 'When searching for a type by type name' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/v1metadata-ns-alias-2020-01-22.xml" -force -wait -warningaction silentlycontinue
            $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault
            $typeManager = $::.TypeManager |=> Get $targetContext
        }

        It 'Should return exactly 1 match when exact match for a valid type name is specified' {
            $searchResults = $typeManager |=> SearchTypes User $true
            $searchResults | Should Not Be $null
            $searchResults.GetType().FullName | Should Be 'System.Management.Automation.PSCustomObject'
            $searchResults.MatchedTypeName | Should be 'microsoft.graph.user'
        }

        It 'Should return 0 matches when exact match for a non-existent type name is specified' {
            $searchResults = $typeManager |=> SearchTypes IDontExist $true
            $searchResults | Should Be $null
        }

        It 'Should return exactly 3 matches when inexact match for a valid type name is specified in a graph schema that has 3 type names that satisfy the inexact match' {
            $searchResults = $typeManager |=> SearchTypes User $false
            $global:myresults = $searchResults
            $searchResults | Should Not Be $null
            $searchResults.GetType().FullName | Should Be 'System.Object[]'
            $searchResults.Length | Should Be 23
            $searchResults[0].MatchedTypeName | Should be 'microsoft.graph.user'
        }

        It 'Should return 0 matches when inexact match for a non-existent type name is specified' {
            $searchResults = $typeManager |=> SearchTypes IDontExist $false
            $searchResults | Should Be $null

            $searchResults = $typeManager |=> SearchTypes IDontExist
            $searchResults | Should Be $null
        }
    }
}

