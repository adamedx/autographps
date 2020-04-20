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

. (join-path $psscriptroot ../../test/common/CompareCustomObject.ps1)

function GetAllTypes {
    'Complex', 'Enumeration', 'Primitive', 'Entity' | foreach {
        $progresspreference = 'silentlycontinue'
        $typeClass = $_
        Get-GraphType -list -typeclass $typeClass | foreach {
            $type = Get-GraphType -TypeClass $typeClass $_
            if ( ! $type ) {
                throw "Unable to retrieve type '$_' of typeclass '$typeClass'"
            }
        }
    }
}

Describe 'The Get-GraphType command' {
    Context 'When invoked using v1 metadata with namespace aliases' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/v1metadata-ns-alias-2020-01-22.xml" -force -wait -warningaction silentlycontinue
        }

        It "Should fail both times to retrieve a nonexistent type" {
            $progresspreference = 'silentlycontinue'
            { get-graphtype idontexist } | Should Throw
            { get-graphtype idontexist } | Should Throw
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Entity when typeclass is not specified" {
            $user = get-graphtype user
            ! (! $user) | Should Be $true
            $useragain = get-graphtype user

            CompareCustomObject $user $useragain | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Entity when typeclass is explicitly specified as entity" {
            $au = get-graphtype -typeclass entity administrativeunit
            ! (! $au) | Should Be $true
            $auagain = get-graphtype -typeclass entity administrativeunit

            CompareCustomObject $au $auagain | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Entity when typeclass is explicitly specified as entity and the fully qualified name is used" {
            $org = get-graphtype -typeclass entity microsoft.graph.organization
            ! (! $org) | Should Be $true
            $orgagain = get-graphtype -typeclass entity microsoft.graph.organization
            $unqualified = get-graphtype -typeclass entity organization

            CompareCustomObject $org $orgagain | Should Be $true
            CompareCustomObject $unqualified $orgagain | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Primitive" {
            $i32 = get-graphtype -typeclass primitive int32
            ! (! $i32) | Should Be $true
            $i32again = get-graphtype -typeclass primitive int32

            CompareCustomObject $i32 $i32again | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Primitive when the fully qualified name is used and the FullyQualifiedTypeName parameter is specified" {
            $i64 = get-graphtype -typeclass primitive Edm.Int64 -fullyqualifiedtypename
            ! (! $i64) | Should Be $true
            $i64again = get-graphtype -typeclass primitive Edm.Int64 -fullyqualifiedtypename
            $unqualified = get-graphtype -typeclass primitive Int64

            CompareCustomObject $i64 $i64again | Should Be $true
            CompareCustomObject $unqualified $i64again | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Enumeration" {
            $tone = get-graphtype -typeclass enumeration tone
            ! (! $tone) | Should Be $true
            $toneagain = get-graphtype -typeclass enumeration tone

            CompareCustomObject $tone $toneagain | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Enumeration when the fully qualified name is used" {
            $phone = get-graphtype -typeclass enumeration microsoft.graph.phonetype
            ! (! $phone) | Should Be $true
            $phoneagain = get-graphtype -typeclass enumeration microsoft.graph.phonetype
            $unqualified = get-graphtype -typeclass enumeration phonetype

            CompareCustomObject $phone $phoneagain | Should Be $true
            CompareCustomObject $unqualified $phoneagain | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Complex" {
            $ipv6 = get-graphtype -typeclass complex ipv6range
            ! (! $ipv6) | Should Be $true
            $ipv6again = get-graphtype -typeclass complex ipv6range

            CompareCustomObject $ipv6 $ipv6again | Should Be $true
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Complex" {
            $phone = get-graphtype -typeclass complex microsoft.graph.phone
            ! (! $phone) | Should Be $true
            $phoneagain = get-graphtype -typeclass complex microsoft.graph.phone
            $unqualified = get-graphtype -typeclass complex microsoft.graph.phone

            CompareCustomObject $phone $phoneagain | Should Be $true
            CompareCustomObject $unqualified $phoneagain | Should Be $true
        }

        It "Should return expected type data for an entity type" {
            $targetProperties = '["activityGroupName","assignedTo","azureSubscriptionId","azureTenantId","category","closedDateTime","cloudAppStates","comments","confidence","createdDateTime","description","detectionIds","eventDateTime","feedback","fileStates","historyStates","hostStates","lastModifiedDateTime","malwareStates","networkConnections","processes","recommendedActions","registryKeyStates","severity","sourceMaterials","status","tags","title","triggers","userStates","vendorInformation","vulnerabilityStates"]' | convertfrom-json

            $targetPropertyTypeIdsSortedByPropertyName = '["Edm.String", "Edm.String", "Edm.String", "Edm.String", "Edm.String", "Edm.DateTimeOffset", "microsoft.graph.cloudAppSecurityState", "Edm.String", "Edm.Int32", "Edm.DateTimeOffset", "Edm.String", "Edm.String", "Edm.DateTimeOffset", "microsoft.graph.alertFeedback", "microsoft.graph.fileSecurityState", "microsoft.graph.alertHistoryState", "microsoft.graph.hostSecurityState", "Edm.DateTimeOffset", "microsoft.graph.malwareState", "microsoft.graph.networkConnection", "microsoft.graph.process", "Edm.String", "microsoft.graph.registryKeyState", "microsoft.graph.alertSeverity", "Edm.String", "microsoft.graph.alertStatus", "Edm.String", "Edm.String", "microsoft.graph.alertTrigger", "microsoft.graph.userSecurityState", "microsoft.graph.securityVendorInformation", "microsoft.graph.vulnerabilityState"]' | convertfrom-json

            $type = Get-GraphType -TypeClass Entity alert

            $type.typeclass | Should Be Entity
            $type.namespace | Should Be microsoft.graph
            $type.TypeId | Should Be microsoft.graph.alert
            $type.BaseType | Should Be microsoft.graph.entity
            $type.Properties.length | Should Be 32

            $type.IsComposite | Should Be $true
            $type.NativeSchema | Should Not Be $null

            CompareCustomObject $type.properties.name $targetProperties | Should Be $true

            $actualPropertyTypeIdsSortedByPropertyName = $type.properties | sort-object name | select -ExpandProperty typeid

            $actualPropertyTypeIdsSortedByPropertyName | convertto-json -depth 4
            CompareCustomObject $actualPropertyTypeIdsSortedByPropertyName $targetPropertyTypeIdsSortedByPropertyName | Should Be $true
        }

        It "Should return expected type data for a primitive type" {
            'int32', 'string', 'boolean', 'DateTimeOffset', 'Date', 'Guid', 'Double' | foreach {
                $type = Get-GraphType -TypeClass Primitive $_

                $type.typeclass | Should Be Primitive
                $type.namespace | Should Be Edm
                $type.TypeId | Should Be Edm.$_
                $type.BaseType | Should Be $null
                $type.Properties | Should Be $null
                $type.IsComposite | Should Be $false
                $type.NativeSchema | Should Not Be $null
            }
        }

        It "Should return expected type data for a complex type" {
            $type = Get-GraphType -TypeClass Complex ipv6Range

            $type.typeclass | Should Be Complex
            $type.namespace | Should Be microsoft.graph
            $type.TypeId | Should Be microsoft.graph.ipv6Range
            $type.BaseType | Should Be microsoft.graph.ipRange
            $type.Properties.length | Should Be 2
            $lowerAddress = $type.Properties | where name -eq lowerAddress
            $upperAddress = $type.Properties | where name -eq upperAddress

            $lowerAddress, $upperAddress | foreach {
                $_.typeid | Should Be Edm.String
                $_.IsCollection | Should Be $false
            }

            $type.IsComposite | Should Be $true
            $type.NativeSchema | Should Not Be $null
        }

        It "Should return expected type data for an enumeration type" {
            $targetProperties = '[{"Name":"tone0","Value":"0"},{"Name":"tone1","Value":"1"},{"Name":"tone2","Value":"2"},{"Name":"tone3","Value":"3"},{"Name":"tone4","Value":"4"},{"Name":"tone5","Value":"5"},{"Name":"tone6","Value":"6"},{"Name":"tone7","Value":"7"},{"Name":"tone8","Value":"8"},{"Name":"tone9","Value":"9"},{"Name":"star","Value":"10"},{"Name":"pound","Value":"11"},{"Name":"a","Value":"12"},{"Name":"b","Value":"13"},{"Name":"c","Value":"14"},{"Name":"d","Value":"15"},{"Name":"flash","Value":"16"}]' | convertfrom-json

            $type = Get-GraphType -TypeClass Enumeration tone

            $type.typeclass | Should Be Enumeration
            $type.namespace | Should Be microsoft.graph
            $type.TypeId | Should Be microsoft.graph.tone
            $type.BaseType | Should Be $null
            $type.Properties.count | Should Be 17
            $type.IsComposite | Should Be $false
            $type.NativeSchema | Should Not Be $null
            CompareCustomObject $type.properties.name $targetProperties | Should Be $true
        }

        It "Should be able to return all types in the newer aliased v1 metadata" {
            { GetAllTypes } | Should Not Throw
        }
    }

    Context 'When invoked using v1 metadata without namespace aliases (i.e. deprecated format)' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/v1metadata-no-ns-alias-2020-01-20.xml" -force -wait -warningaction silentlycontinue
        }

        It "Should be able to successfully return the same data in successive calls for a type of typeclass Entity when typeclass is not specified" {
            $progresspreference = 'silentlycontinue'
            $user = get-graphtype user
            ! (! $user) | Should Be $true
        }

        It "Should be able to return all non-primitive types in the older non-aliased v1 metadata" {
            { GetAllTypes } | Should Not Throw
        }
    }
}

