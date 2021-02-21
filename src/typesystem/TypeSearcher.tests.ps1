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
            $searchResults = $typeManager |=> SearchTypes User Name Entity Exact
            $searchResults | Should Not Be $null
            $searchResults.GetType().FullName | Should Be 'System.Management.Automation.PSCustomObject'
            $searchResults.MatchedTypeName | Should be 'microsoft.graph.user'
        }

        It 'Should return 0 matches when exact match for a non-existent type name is specified' {
            $searchResults = $typeManager |=> SearchTypes IDontExist Name Entity Exact
            $searchResults | Should Be $null
        }

        It 'Should return exactly 4 matches when startswith match for a valid type name is specified in a graph schema that has 3 type names that satisfy the startswith match' {
            $searchResults = $typeManager |=> SearchTypes User Name Entity StartsWith
            $searchResults | Should Not Be $null
            $searchResults.GetType().FullName | Should Be 'System.Object[]'
            $searchResults.Length | Should Be 4

            'microsoft.graph.useractivity',
            'microsoft.graph.user',
            'microsoft.graph.userinstallstatesummary',
            'microsoft.graph.usersettings' | foreach {
                $searchResults.MatchedTypeName -contains $_
            }
        }

        It 'Should return 0 matches when startswith match for a non-existent type name is specified' {
            $searchResults = $typeManager |=> SearchTypes IDontExist Name Entity StartsWith
            $searchResults | Should Be $null
        }
    }
}

