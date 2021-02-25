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

        It "Should return 13 matches for the entity type user by name index with a contains match" {
            $searchResults = $typeManager |=> SearchTypes User Name Entity Contains | sort-object score -descending
            $matchedTypesSortedByScore = @('microsoft.graph.user'
                              'microsoft.graph.outlookuser'
                              'microsoft.graph.usersettings'
                              'microsoft.graph.educationuser'
                              'microsoft.graph.deviceconfigurationuseroverview'
                              'microsoft.graph.devicecomplianceuseroverview'
                              'microsoft.graph.userinstallstatesummary'
                              'microsoft.graph.manageddevicemobileappconfigurationusersummary'
                              'microsoft.graph.devicecomplianceuserstatus'
                              'microsoft.graph.manageddevicemobileappconfigurationuserstatus'
                              'microsoft.graph.planneruser'
                              'microsoft.graph.deviceconfigurationuserstatus'
                              'microsoft.graph.useractivity')

            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length
            $typeIndex = 0
            $searchResults | where { $_.MatchedTypeName -in $matchedTypesSortedByScore[$typeIndex++] } | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            $searchResults | where MatchedTypeClass -eq Entity | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length
            $searchResults | where { $_.Criteria.count -eq 1 -and $_.Criteria.keys[0] -eq 'Name' } | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length
        }

        It "Should return 3 types that can be sorted by score, one complex, one entity, one enumeration, when searching name index for tone for any type class with contains match" {
            $searchResults = $typeManager |=> SearchTypes Tone Name Enumeration, Complex, Entity Contains
            $matchedTypesSortedByScore = @('microsoft.graph.tone'
                              'microsoft.graph.toneinfo'
                              'microsoft.graph.subscribetotoneoperation')
            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            $typeIndex = 0
            $searchResults | sort Score -descending | where { $_.MatchedTypeName -eq $matchedTypesSortedByScore[$typeIndex++] } | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            'Entity' -in $searchResults.MatchedTypeClass | Should Be $true
            'Complex' -in $searchResults.MatchedTypeClass | Should Be $true
            'Enumeration' -in $searchResults.MatchedTypeClass | Should Be $true

            $searchResults | where {
                $_.Criteria.count -eq 1 -and $_.Criteria.keys[0] -eq 'Name'
            } | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

        }

        It "Should return all 3 type classes for types sortable by score when searching for mailbox in all 3 typeclasses with name and property and startswith match" {
            $searchResults = $typeManager |=> SearchTypes mailbox Name, Property Enumeration, Complex, Entity StartsWith | sort-object score -descending
            $matchedTypesSortedByScore = @('microsoft.graph.mailboxsettings'
                              'microsoft.graph.user'
                              'microsoft.graph.mailtipstype'
                              'microsoft.graph.mailtips')
            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            $typeIndex = 0
            $searchResults | where { $_.MatchedTypeName -eq $matchedTypesSortedByScore[$typeIndex++] } | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            $searchResults[0].MatchedTypeClass -eq 'Complex' | Should Be $true
            $searchResults[1].MatchedTypeClass -eq 'Entity' | Should Be $true
            $searchResults[2].MatchedTypeClass -eq 'Enumeration' | Should Be $true
            $searchResults[3].MatchedTypeClass -eq 'Complex' | Should Be $true

            $searchResults[0].Criteria['Name'] -ne $null | Should Be $true
            $searchResults[1].Criteria['Property'] -ne $null | Should Be $true
            $searchResults[2].Criteria['Property'] -ne $null | Should Be $true
            $searchResults[3].Criteria['Property'] -ne $null | Should Be $true
        }

        It "Should match exactly 'sendMail' when searching Index method for all 3 typeclasses using StartsWith" {
            $searchResults = $typeManager |=> SearchTypes sendmail method Enumeration, Complex, Entity StartsWith
            $searchResults | measure-object | select-object -expandproperty count | Should Be 1
            $searchResults.MatchedTypeName -eq 'sendMail'
            $searchResults.Criteria['Method'] -ne $null | Should Be $true
        }

        It "Should return 6 methods sortable by score when searching for send method across name, property, method for typeclass entity using StartsWith" {
            $matchedTypesSortedByScore = @('microsoft.graph.message'
                              'microsoft.graph.inferenceclassificationoverride'
                              'microsoft.graph.invitation'
                              'microsoft.graph.post'
                              'microsoft.graph.notificationmessagetemplate'
                              'microsoft.graph.user')
            $searchResults = $typeManager |=> SearchTypes send Name, property, method Entity StartsWith | sort-object score -descending

            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length
            $typeIndex = 0
            $searchResults | where { $_.MatchedTypeName -eq $matchedTypesSortedByScore[$typeIndex++] } | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            $searchResults | where MatchedTypeClass -eq Entity | measure-object | select -expandproperty count | Should Be $matchedTypesSortedByScore.length

            $searchResults[0].Criteria['Property'] -ne $null -and $searchResults[0].Criteria['Method'] -ne $null | Should Be $true
            $searchResults[1].Criteria['Property'] -ne $null | Should Be $true
            $searchResults[2].Criteria['Property'] -ne $null | Should Be $true
            $searchResults[3].Criteria['Property'] -ne $null | Should Be $true
            $searchResults[4].Criteria['Method'] -ne $null | Should Be $true
            $searchResults[5].Criteria['Method'] -ne $null | Should Be $true
        }
    }
}

