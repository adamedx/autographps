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
            $searchResults = $typeManager |=> SearchTypes User Name Entity Contains
            $matchedTypes = @{'microsoft.graph.user' = 33
                                           'microsoft.graph.devicecomplianceuseroverview' = 17
                                           'microsoft.graph.devicecomplianceuserstatus' = 17
                                           'microsoft.graph.deviceconfigurationuseroverview' = 17
                                           'microsoft.graph.deviceconfigurationuserstatus' = 17
                                           'microsoft.graph.educationuser' = 17
                                           'microsoft.graph.manageddevicemobileappconfigurationuserstatus' = 17
                                           'microsoft.graph.manageddevicemobileappconfigurationusersummary' = 17
                                           'microsoft.graph.outlookuser' = 17
                                           'microsoft.graph.planneruser' = 17
                                           'microsoft.graph.useractivity' = 17
                                           'microsoft.graph.userinstallstatesummary' = 17
                                           'microsoft.graph.usersettings' = 17}

            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            $searchResults | where { $matchedTypes[$_.MatchedTypeName] -eq $_.score } | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            $searchResults | where MatchedTypeClass -eq Entity | measure-object | select -expandproperty count | Should Be $matchedTypes.count
            $searchResults | where { $_.Criteria.count -eq 1 -and $_.Criteria.keys[0] -eq 'Name' } | measure-object | select -expandproperty count | Should Be $matchedTypes.count
        }

        It "Should return 3 types that can be sorted by score, one complex, one entity, one enumeration, when searching name index for tone for any type class with contains match" {
            $searchResults = $typeManager |=> SearchTypes Tone Name Enumeration, Complex, Entity Contains
            $matchedTypes = @{'microsoft.graph.tone' = 33
                              'microsoft.graph.toneinfo' = 17
                              'microsoft.graph.subscribetotoneoperation' = 17}
            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            $searchResults | where { $matchedTypes[$_.MatchedTypeName] -eq $_.score } | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            'Entity' -in $searchResults.MatchedTypeClass | Should Be $true
            'Complex' -in $searchResults.MatchedTypeClass | Should Be $true
            'Enumeration' -in $searchResults.MatchedTypeClass | Should Be $true

            $searchResults | where {
                $_.Criteria.count -eq 1 -and $_.Criteria.keys[0] -eq 'Name'
            } | measure-object | select -expandproperty count | Should Be $matchedTypes.count

        }

        It "Should return all 3 type classes for types sortable by score when searching for mailbox in all 3 typeclasses with name and property and startswith match" {
            $searchResults = $typeManager |=> SearchTypes mailbox Name, Property Enumeration, Complex, Entity StartsWith | sort-object matchedtypename | sort-object score -descending
            $matchedTypes = @{'microsoft.graph.mailboxsettings' = 17
                              'microsoft.graph.user' = 9
                              'microsoft.graph.mailtipstype' = 9
                              'microsoft.graph.mailtips' = 9}
            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            $searchResults | where { $matchedTypes[$_.MatchedTypeName] -eq $_.score } | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.mailboxsettings' | select -expandproperty MatchedTypeClass) -eq 'Complex' | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.user' | select -expandproperty MatchedTypeClass) -eq 'Entity' | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.mailtipstype' | select -expandproperty MatchedTypeClass) -eq 'Enumeration' | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.mailtips' | select -expandproperty MatchedTypeClass) -eq 'Complex' | Should Be $true

            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.mailboxsettings').Criteria['Name'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.user').Criteria['Property'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.mailtipstype').Criteria['Property'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.mailtips').Criteria['Property'] -ne $null | Should Be $true
        }

        It "Should match exactly 'sendMail' when searching Index method for all 3 typeclasses using StartsWith" {
            $searchResults = $typeManager |=> SearchTypes sendmail method Enumeration, Complex, Entity StartsWith
            $searchResults | measure-object | select-object -expandproperty count | Should Be 1
            $searchResults.MatchedTypeName -eq 'sendMail'
            $searchResults.Criteria['Method'] -ne $null | Should Be $true
        }

        It "Should return 6 methods sortable by score when searching for send method across name, property, method for typeclass entity using StartsWith" {
            $matchedTypes = @{'microsoft.graph.message' = 12
                              'microsoft.graph.inferenceclassificationoverride' = 9
                              'microsoft.graph.invitation' = 9
                              'microsoft.graph.post' = 9
                              'microsoft.graph.notificationmessagetemplate' = 5
                              'microsoft.graph.user' = 5}
            $searchResults = $typeManager |=> SearchTypes send Name, property, method Entity StartsWith | sort-object matchedtypename | sort-object score -descending

            $searchResults | measure-object | select -expandproperty count | Should Be $matchedTypes.count
            $searchResults | where { $matchedTypes[$_.MatchedTypeName] -eq $_.score } | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            $searchResults | where MatchedTypeClass -eq Entity | measure-object | select -expandproperty count | Should Be $matchedTypes.count

            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.message').Criteria['Property'] -ne $null -and $searchResults[0].Criteria['Method'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.inferenceclassificationoverride').Criteria['Property'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.invitation').Criteria['Property'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.post').Criteria['Property'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.notificationmessagetemplate').Criteria['Method'] -ne $null | Should Be $true
            ($searchResults | where MatchedTypeName -eq 'microsoft.graph.user').Criteria['Method'] -ne $null | Should Be $true
        }
    }
}

