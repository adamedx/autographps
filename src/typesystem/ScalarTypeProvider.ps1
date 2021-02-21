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

. (import-script TypeSchema)
. (import-script TypeIndex)

ScriptClass ScalarTypeProvider {
    $base = $null
    $primitiveDefinitions = $null
    $enumerationDefinitions = $null
    $primitiveNames = $null
    $indexes = $null

    function __initialize($graph) {
        $this.indexes = $null

        $this.base = new-so TypeProvider $this $graph

        LoadEnumerationTypeDefinitions
        LoadPrimitiveTypeDefinitions
    }

    function GetTypeDefinition($typeClass, $typeId) {
        $this.scriptclass |=> ValidateTypeClass $typeClass

        switch ( $typeClass ) {
            'Primitive' {
                GetPrimitiveDefinition $typeId
                break
            }
            'Enumeration' {
                GetEnumerationDefinition $typeId
                break
            }
        }
    }

    function GetSortedTypeNames($typeClass) {
        $this.scriptclass |=> ValidateTypeClass $typeClass

        switch ( $typeClass ) {
            'Primitive' {
                if ( ! $this.primitiveNames ) {
                    $this.primitiveNames = $this.primitiveDefinitions.keys | sort
                }
                $this.primitiveNames
                break
            }
            'Enumeration' {
                $this.enumerationDefinitions.keys
                break
            }
        }
    }

    function GetTypeIndexes([string[]] $indexFields, [string[]] $typeClasses) {
        # Note that we initialize all indexes as well as the only supported
        # type class, even if they are not asked for at the end we do
        # filter for only the requested indexes
        if ( 'Enumeration' -in $typeClasses -and ! $this.indexes ) {
            $nameIndex = new-so TypeIndex Name
            $propertyIndex = new-so TypeIndex Property

            foreach ( $typeId in $this.enumerationDefinitions.Keys ) {
                $enumerationDefinition = $this.enumerationDefinitions[$typeId]
                $nameIndex |=> Add $typeId $typeId Enumeration
                foreach ( $property in $enumerationDefinition.Properties ) {
                    $propertyIndex |=> Add $property.Name.Name $typeId Enumeration
                }
            }

            $this.indexes = $nameIndex, $propertyIndex

            foreach ( $index in $this.indexes ) {
                $index |=> SetContext TypeClass Enumeration
            }
        }

        # Be sure to return only the indexes actually requested
        if ( $this.indexes ) {
            $this.indexes.Values | where IndexedField -in $indexFields
        }
    }

    function UpdateTypeIndexes($indexes, [string[]] $typeClasses) {
        if ( 'Enumeration' -in $typeClasses -and ! $this.indexes ) {
            $nameIndex = $indexes | where IndexedField -eq Name
            $propertyIndex = $indexes | where IndexedField -eq Property

            foreach ( $typeId in $this.enumerationDefinitions.Keys ) {
                $enumerationDefinition = $this.enumerationDefinitions[$typeId]
                if( $nameIndex ) {
                    $nameIndex |=> Add $typeId $typeId Enumeration
                }

                if ( $propertyIndex ) {
                    foreach ( $property in $enumerationDefinition.Properties ) {
                        $propertyIndex |=> Add $property.Name.Name $typeId Enumeration
                    }
                }
            }

            foreach ( $index in $this.indexes ) {
                $index |=> SetContext TypeClass Enumeration
            }
        }
    }

    function LoadEnumerationTypeDefinitions {
        $enumerationDefinitions = [System.Collections.Generic.SortedList[String, Object]]::new()
        $nativeSchemas = $this.base.graph |=> GetEnumTypes

        $nativeSchemas | foreach {
            $properties = [ordered] @{}

            $_.Schema.member | foreach {
                $memberData = [PSCustomObject] @{
                    Type = 'Edm.String'
                    Name = [PSCUstomObject] @{Name=$_.name;Value=$_.value}
                }

                # TODO: The 'name' field is being misused here -- a previous implementation relied on this structure
                # being in the name field. Now that we are using TypeMember instead of an arbitrary structure, we can
                # just let consumers use the MemberData field and let name just be a name.
                $propertyValue = new-so TypeMember ([PSCUstomObject] @{Name=$_.name;Value=$_.value}) 'Edm.String' $false Enumeration $memberData
                $properties.Add($_.name, $propertyValue)
            }

            $enumerationValues = $properties.Values
            $defaultValue = if ( $enumerationValues.count -gt 0 ) {
                $enumerationValues | select -first 1 | select -expandproperty name | select -expandproperty name
            }

            $typeId = $this.base.graph |=> UnaliasQualifiedName $_.QualifiedName

            $definition = new-so TypeDefinition $typeId Enumeration $_.Schema.name $_.Namespace $null $enumerationValues $defaultValue $null $false $_.Schema
            $enumerationDefinitions.Add($typeId.tolower(), $definition)
        }

        $this.enumerationDefinitions = $enumerationDefinitions
    }

    function LoadPrimitiveTypeDefinitions {
        # See data type documentation at http://docs.oasis-open.org/odata/odata-csdl-json/v4.01/odata-csdl-json-v4.01.html#_Toc26353363
        # for a list of all supported OData primitive types
        $this.primitiveDefinitions = @{
            'Byte' = @{Name='Byte';Type=[byte];DefaultValue={0};DefaultCollectionValue={return , [byte[]]@(0)}}
            'Int16' = @{Name='Int16';Type=[int32];DefaultValue={0};DefaultCollectionValue={return , [int16[]]@(0)}}
            'Int32' = @{Name='Int32';Type=[int32];DefaultValue={0};DefaultCollectionValue={return , [int32[]]@(0)}}
            'Int64' = @{Name='Int64';Type=[int64];DefaultValue={0};DefaultCollectionValue={return , [int64[]]@(0)}}
            'Double' = @{Name='Double';Type=[double];DefaultValue={0};DefaultCollectionValue={return , [double[]]@(0)}}
            'Decimal' = @{Name='Decimal';Type=[double];DefaultValue={0};DefaultCollectionValue={return , [double[]]@(0)}}
            'Single' = @{Name='Single';Type=[single];DefaultValue={0};DefaultCollectionValue={return , [single[]]@(0)}}
            'String' = @{Name='String';Type=[string];DefaultValue={''};DefaultCollectionValue={return , [string[]]@('')}}
            'Boolean' = @{Name='Boolean';Type=[bool];DefaultValue={$false};DefaultCollectionValue={return , [bool[]]@($false)}}
            'Stream' = @{Name='Stream';Type=[byte[]];DefaultValue={[byte[]]@()};DefaultCollectionValue={return , [byte[][]]@([byte[][]]@([byte[]]@()))}}
            'Guid' = @{Name='Guid';Type=[Guid];DefaultValue={([Guid] '00000000-0000-0000-0000-000000000000')};DefaultCollectionValue={return , [Guid[]]@(([Guid] '00000000-0000-0000-0000-000000000000'))}}
            'DateTimeOffset' = @{Name='Date';Type=[DateTimeOffset];DefaultValue={[DateTimeOffset]::new([DateTime]::new([DateTime]::Now.Year, 1, 1))};DefaultCollectionValue={return , @([DateTimeOffset]::new([DateTime]::new([DateTime]::Now.Year, 1, 1)))}}
            'Duration' = @{Name='Duration';Type=[TimeSpan];DefaultValue={[TimeSpan]::new(0)};DefaultCollectionValue={return , [TimeSpan[]]@([TimeSpan]::new(0))}}
            'Binary' = @{Name='Binary';Type=[byte[]];DefaultValue={[byte[]]@()};DefaultCollectionValue={return , [byte[][]]@([byte[][]]@([byte[]]@()))}}
            'Date' = @{Name='Date';Type=[string];DefaultValue={[DateTime]::new(0).tostring("s") + "Z"};DefaultCollectionValue={return , [String[]]@([DateTime]::new(0).tostring("s") + "Z")}}
            'TimeOfDay' = @{Name='TimeOfDay';Type=[string];DefaultValue={[DateTime]::new(0).tostring("s") + "Z"};DefaultCollectionValue={return , [String[]]@([DateTime]::new(0).tostring("s") + "Z")}}
        }
    }

    function GetEnumerationDefinition($typeId) {
        $definition = $this.enumerationDefinitions[$typeId.tolower()]

        if ( ! $definition ) {
            throw "Enumeration type '$typeId' does not exist"
        }

        $definition
    }

    function GetPrimitiveDefinition($typeId) {
        if ( ! ( $this.scriptclass |=> IsPrimitiveType $typeId ) ) {
            throw "Type '$typeId' is not a primitive type"
        }

        $nameInfo = $::.TypeSchema |=> GetTypeNameInfo $this.scriptclass.PRIMITIVE_TYPE_NAMESPACE $typeId
        $unqualifiedName = $nameInfo.name

        $nativeSchema = $this.primitiveDefinitions[$unqualifiedName]

        if ( ! $nativeSchema ) {
            throw "No primitive type '$typeId' exists"
        }

        new-so TypeDefinition $typeId Primitive $nativeSchema.name $this.scriptclass.PRIMITIVE_TYPE_NAMESPACE $null $null $nativeSchema.DefaultValue $nativeSchema.DefaultCollectionValue $false $nativeSchema
    }

    static {
        const PRIMITIVE_TYPE_NAMESPACE Edm

        function GetTypeProvider($graph) {
            $::.TypeProvider |=> GetTypeProvider $this $graph
        }

        function IsPrimitiveType($typeId) {
            $primitivePrefix = $this.PRIMITIVE_TYPE_NAMESPACE + '.'
            $typePrefix = $typeId.substring(0, $primitivePrefix.length)
            $typePrefix -eq $primitivePrefix
        }

        function ValidateTypeClass($typeClass) {
            $::.TypeProvider |=> ValidateTypeClass $this $typeClass
        }

        function GetSupportedTypeClasses {
            @('Primitive', 'Enumeration')
        }

        function GetDefaultNamespace($typeClass, $graph) {
            if ( $typeClass -eq 'Primitive' ) {
                $this.PRIMITIVE_TYPE_NAMESPACE
            } else {
                $graph |=> GetDefaultNamespace
            }
        }

        function ValidateTypeClass($typeClass) {
            $::.TypeProvider |=> ValidateTypeClass $this $typeClass
        }
    }
}
