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

# This test assumes the module has been imported

. (join-path $psscriptroot ../../test/common/CompareCustomObject.ps1)

function GetAllObjects {
    'Complex', 'Enumeration', 'Primitive', 'Entity' | foreach {
        $typeClass = $_
        Get-GraphType -list -typeclass $typeClass | foreach {
            $objectJson = New-GraphObject -TypeClass $typeClass $_ -json -setdefaultvalues -recurse
            if ( ! $objectJson -and ( $typeClass -ne 'Primitive' -and $_ -ne 'Binary' ) ) {
                throw "Unable to create a new object of type '$_' of typeclass '$typeClass'"
            }
        }
    }
}

Describe 'The New-GraphObject command' {
    Context 'When invoked using v1 metadata with v1 metadata' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/v1metadata-ns-alias-2020-01-22.xml" -force -wait -warningaction silentlycontinue
        }

        It 'Should emit an array object for a given property even when the array specified by the value parameter has only one element when the type of the property is an array' {
            $emailAddress = New-GraphObject -TypeClass Complex emailAddress -Property name, address -value Home, sorry@thisman.org
            $contactdata = New-GraphObject microsoft.graph.contact -PropertyMap @{givenName='SorryTo ThisMan';emailAddresses = @($emailAddress)}

            $expectedContactData = @{givenName='SorryTo ThisMan';emailAddresses=@(@{name='Home';Address='sorry@thisman.org'})}
            $expectedJSON = $expectedContactData | ConvertTo-Json -Compress

            $contactData.emailAddresses.GetType().isarray | Should Be $true
            $contactData | convertTo-json -compress | Should Be $expectedJSON
        }

        It 'Should emit an array object for a given property even when the array specified by the PropertyMap parameter has only one element when the type of the property is an array' {
            $emailAddress = New-GraphObject -TypeClass Complex emailAddress -Property name, address -value Home, sorry@thisman.org
            $contactdata = New-GraphObject microsoft.graph.contact -PropertyMap @{givenName='SorryTo ThisMan';emailAddresses = @($emailAddress)}

            $expectedContactData = @{givenName='SorryTo ThisMan';emailAddresses=@(@{name='Home';Address='sorry@thisman.org'})}
            $expectedJSON = $expectedContactData | ConvertTo-Json -Compress

            $contactData.emailAddresses.GetType().isarray | Should Be $true
            $contactData | convertTo-json -compress | Should Be $expectedJSON
        }

        It 'Should throw an error if a property is specified through the Property parameter that does not exist for the specified type' {
            # Check for three different strings because properties in the error output can be returned in non-deterministic order
            { New-GraphObject user -Property displayName, idontexist, neitherdoi, userPrincipalName } | Should Throw "One or more specified properties is not a valid property for type 'user'"
            { New-GraphObject user -Property displayName, idontexist, neitherdoi, userPrincipalName } | Should Throw 'idontexist'
            { New-GraphObject user -Property displayName, idontexist, neitherdoi, userPrincipalName } | Should Throw 'neitherdoi'
        }

        It 'Should throw an error if a property is specified through the PropertyMap parameter that does not exist for the specified type' {
            # Check for three different strings because properties in the error output can be returned in non-deterministic order
            { New-GraphObject user -PropertyMap @{displayName='hi';idontexist='yes';neitherdoi='no';userPrincipalName='a@b.com'} } | Should Throw "One or more specified properties is not a valid property for type 'user'"
            { New-GraphObject user -PropertyMap @{displayName='hi';idontexist='yes';neitherdoi='no';userPrincipalName='a@b.com'} } | Should Throw 'idontexist'
            { New-GraphObject user -PropertyMap @{displayName='hi';idontexist='yes';neitherdoi='no';userPrincipalName='a@b.com'} } | Should Throw 'neitherdoi'
        }

        It 'Should not throw an error if SkipPropertyCheck is specified and a property is specified through the Property parameter that does not exist for the specified type' {
            { New-GraphObject user -SkipPropertyCheck -Property displayName, idontexist, neitherdoi, userPrincipalName } | Should Not Throw
        }

        It 'Should not throw an error if SkipPropertyCheck is specified and a property is specified through the PropertyMap parameter that does not exist for the specified type' {
            { New-GraphObject user -SkipPropertyCheck -Property displayName, idontexist, neitherdoi, userPrincipalName } | Should Not Throw
        }

        It 'Should be able to return all the objects in the v1 metadata' {
            { GetAllObjects } | Should Not Throw
        }
    }

    Context 'When invoked using beta metadata with namespace aliases and multiple namepaces' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/betametadata-ns-alias-multi-namespace-2020-03-25.xml" -force -wait -warningaction silentlycontinue
        }

        It "Should be able to get an object in the 'microsoft.graph' namespace" {
            $expected = get-content "$psscriptroot/../../test/assets/NewGraphBetaObjectApplication.json" | out-string | convertfrom-json
            $expectedProperties = $expected | gm -membertype noteproperty

            $actual = new-graphobject microsoft.graph.application -SetDefaultValues | convertto-json | convertfrom-json
            $actualProperties = $actual | gm -membertype noteproperty

            $expectedProperties.length | Should Be $actualProperties.length
            $expectedProperties | foreach {
                $actualProperties | where name -eq $_.name | Should Not be $null
                ( $expected | select -expandproperty $_.name ) | Should Be ( $actual | select -expandproperty $_.name )
            }
        }

        It "Should be able to get an object in the 'microsoft.graph.callRecords' namespace" {
            $expected = get-content "$psscriptroot/../../test/assets/NewGraphBetaObjectCallRecord.json" | out-string | convertfrom-json
            $expectedProperties = $expected | gm -membertype noteproperty

            $actual = new-graphobject microsoft.graph.callRecords.callRecord -SetDefaultValues | convertto-json | convertfrom-json
            $actualProperties = $actual | gm -membertype noteproperty

            $expectedProperties.length | Should Be $actualProperties.length
            $expectedProperties | foreach {
                $actualProperties | where name -eq $_.name | Should Not be $null
                ( $expected | select -expandproperty $_.name ) | Should Be ( $actual | select -expandproperty $_.name )
            }
        }

        It 'Should be able to return all objects in the beta metadata' {
            { GetAllObjects } | Should Not Throw
        }
    }
}

