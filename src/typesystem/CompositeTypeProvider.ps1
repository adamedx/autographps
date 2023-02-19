# Copyright 2021, Adam Edwards
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
. (import-script MethodInfo)
. (import-script TypeDefinition)
. (import-script TypeIndex)

ScriptClass CompositeTypeProvider {
    $base = $null
    $entityTypeTable = $null
    $complexTypeTable = $null
    $indexes = $null

    function __initialize($graph) {
        $this.base = new-so TypeProvider $this $graph
        $this.indexes = [ordered] @{}

        'Name', 'Property', 'NavigationProperty', 'Method' | foreach {
            $this.indexes[$_] = new-so TypeIndex $_
        }
    }

    function GetTypeDefinition($typeClass, $typeId, $ignoreNotFound) {
        if ( $typeClass -ne 'Entity' -and $typeClass -ne 'Complex' -and $typeClass -ne 'Unknown' ) {
            throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
        }

        $nativeSchema = GetNativeSchemaFromGraph $typeId $typeClass

        if ( ! $nativeSchema ) {
            if ( $ignoreNotFound ) {
                return
            }
            throw "Unable to find type '$typeId' of typeclass '$typeClass"
        }

        $foundTypeClass = if ( $typeClass -ne 'Unknown' ) {
            $typeClass
        } elseif ( $nativeSchema.SchemaClass -eq 'EntityType' ) {
            'Entity'
        } elseif ( $nativeSchema.SchemaClass -eq 'ComplexType' ) {
            'Complex'
        } else {
            throw "Found invalid native schema of type '$($nativeSchema.SchemaClass)' for type '$typeId': the only valid values are 'ComplexType' and 'EntityType'"
        }

        $properties = if ( $nativeSchema.Schema | gm property -erroraction ignore ) {
            foreach ( $propertySchema in $nativeSchema.Schema.Property ) {
                $typeInfo = $::.TypeSchema.GetNormalizedPropertyTypeInfo($nativeSchema.namespace, $propertySchema.Type)
                $unaliasedPropertyTypeName = $this.base.graph.UnaliasQualifiedName($typeInfo.TypeFullName)
                new-so TypeMember $propertySchema.Name $unaliasedPropertyTypeName $typeInfo.IsCollection Property $null $typeid
            }
        }

        $navigationProperties = if ( $nativeSchema.Schema | gm navigationproperty -erroraction ignore ) {
            foreach ( $navigationProperty in $nativeSchema.Schema.NavigationProperty ) {
                $navigationInfo = $::.TypeSchema.GetNormalizedPropertyTypeInfo($nativeSchema.namespace, $navigationproperty.Type)
                $unaliasedNavigationPropertyTypeName = $this.base.graph.UnAliasQualifiedName($navigationInfo.TypeFullName)
                new-so TypeMember $navigationproperty.Name $unaliasedNavigationPropertyTypeName $navigationInfo.IsCollection NavigationProperty $null $typeId
            }
        }

        $methodSchemas = GetMethodSchemasForType $typeId

        $methods = if ( $methodSchemas ) {
            foreach ( $methodSchema in $methodSchemas ) {
                $memberData = new-so MethodInfo $this.base.graph $methodSchema.NativeSchema $methodSchema.MethodType $typeId
                new-so TypeMember $methodSchema.NativeSchema.Name $null $false Method $memberData $typeId
            }
        }

        $qualifiedBaseTypeName  = if ( $nativeSchema.Schema | gm BaseType -erroraction ignore) {
            $this.base.graph.UnAliasQualifiedName($nativeSchema.Schema.BaseType)
        }

        new-so TypeDefinition $typeId $foundTypeClass $nativeSchema.Schema.name $nativeSchema.namespace $qualifiedBaseTypeName $properties $null $null $true $nativeSchema.Schema $navigationProperties $methods
    }

    function GetSortedTypeNames($typeClass) {
        $this.scriptclass.ValidateTypeClass($typeClass)

        switch ( $typeClass ) {
            'Entity' {
                (GetEntityTypeSchemas).get_Keys()
                break
            }
            'Complex' {
                (GetComplexTypeSchemas).get_Keys()
                break
            }
        }
    }

    function UpdateTypeIndexes($indexes, $typeClasses) {
        $targetClasses = $typeClasses | where { $_ -in @('Entity', 'Complex') }

        if ( $targetClasses ) {
            foreach ( $index in $indexes ) {

                if ( 'Entity' -in $targetClasses ) {
                    $entitySchemas = GetEntityTypeSchemas
                    __UpdateTypeIndex $index $entitySchemas Entity
                }

                if ( 'Complex' -in $targetClasses ) {
                    $complexSchemas = GetComplexTypeSchemas
                    __UpdateTypeIndex $index $complexSchemas Complex
                }
            }
        }
    }

    function GetComplexTypeSchemas {
        if ( ! $this.complexTypeTable ) {
            $complexTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $complexTypeSchemas = $this.base.graph |=> GetComplexTypes
            UpdateTypeTable $complexTypeTable $complexTypeSchemas $true
            $this.complexTypeTable = $complexTypeTable
        }

        $this.complexTypeTable
    }

    function GetEntityTypeSchemas {
        if ( ! $this.entityTypeTable ) {
            $entityTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $entityTypeSchemas = $this.base.graph |=> GetEntityTypes
            UpdateTypeTable $entityTypeTable $entityTypeSchemas $true
            $this.entityTypeTable = $entityTypeTable
        }

        $this.entityTypeTable
    }

    function GetMethodSchemasForType($qualifiedTypeName) {
        $methodSchemas = $this.base.graph.GetMethodsForType($qualifiedTypeName)

        if ( $methodSchemas ) {
            foreach ( $methodSchema in $methodSchemas ) {
                [PSCustomObject] @{
                    MethodType = $methodSchema.Type
                    NativeSchema = $methodSchema.Schema
                }
            }
        }
     }

    function UpdateTypeTable($typeTable, $typeSchemas, $ignoreExisting) {
        foreach ( $schema in $typeSchemas ) {
            $qualifiedTypeName = $schema.QualifiedName.tolower()
            if ( ! $ignoreExisting -or ! $typeTable[$qualifiedTypeName] ) {
                $qualifiedTypeName = $schema.QualifiedName
                $typeTable.Add($qualifiedTypeName.tolower(), $schema)
            }
        }
    }

    function GetTypeByName($typeClass, $typeName) {
        $typeTable = if ( $typeClass -eq 'Entity' ) {
            GetEntityTypeSchemas
        } else {
            GetComplexTypeSchemas
        }

        $typeTable[$typeName.tolower()]
    }

    function GetNativeSchemaFromGraph($qualifiedTypeName, $typeClass) {
        $unaliasedTypeName = $this.base.graph.UnAliasQualifiedName($qualifiedTypeName)
        $nativeSchema = if ( $typeClass -eq 'Entity' -or $typeClass -eq 'Unknown' ) {
            GetTypeByName Entity $unaliasedTypeName
        }

        if ( ! $nativeSchema -and ( $typeClass -eq 'Complex' -or $typeClass -eq 'Unknown' ) ) {
            $nativeSchema = GetTypeByName Complex $unaliasedTypeName
        }

        if ( ! $nativeSchema ) {
            throw "Schema for type '$qualifiedTypeName' unaliased as '$unaliasedTypeName' of type class '$typeClass' was not found in Graph '$($this.base.graph.ApiVersion)'"
        }

        $nativeSchema
    }

    function __UpdateTypeIndex($index, $schemas, $typeClass) {
        $schemaCount = ($schemas.get_keys() | measure-object).count

        $schemasProcessed = 0

        $activityMessage = "Updating search index '$($index.IndexedField)' for type class '$typeClass'"

        Write-Progress -id 1 -activity $activityMessage

        foreach ( $typeId in $schemas.get_Keys() ) {
            $nativeSchema = $schemas[$typeId]

            if ( $schemasProcessed++ % 10 -eq 0 ) {
                $percent = ( $schemasProcessed / $schemaCount ) * 100
                Write-Progress -id 1 -activity $activityMessage -PercentComplete $percent
            }

            switch ( $index.IndexedField ) {
                'Name' {  $index.Add($typeId, $typeId, $typeClass) }
                'Property' {
                    if ( $nativeSchema.Schema | gm property -erroraction ignore ) {
                        foreach ( $property in $nativeSchema.Schema.property ) {
                            $index.Add($property.Name, $typeId, $typeClass)
                        }
                    }
                }
                'NavigationProperty' {
                    if ( $nativeSchema.Schema | gm navigationproperty -erroraction ignore ) {
                        foreach ( $navigationProperty in $nativeSchema.Schema.navigationproperty ) {
                            $index.Add($navigationProperty.Name, $typeId, $typeClass)
                        }
                    }
                }
                'Method' {
                    $methodSchemas = GetMethodSchemasForType $typeId
                    if ( $methodSchemas ) {
                        $methodSchemaCount = ($methodSchemas | measure-object).count
                        Write-Progress -id 2 -activity "Updating search index 'method' with $methodSchemaCount schema(s)for type '$typeId'" -ParentId 1
                        foreach ( $nativeMethodSchema in $methodSchemas.NativeSchema ) {
                            $index.Add($nativeMethodSchema.Name, $typeId, $typeClass)
                        }
                    }
                }
                default {
                    throw "Unknown field name '$($index.IndexedField)'"
                }
            }
        }
        Write-Progress -id 1 -activity $activityMessage -Completed
    }

    static {
        function GetTypeProvider($graph) {
            $::.TypeProvider |=> GetTypeProvider $this $graph
        }

        function GetSupportedTypeClasses {
            @('Entity', 'Complex')
        }

        function GetDefaultNamespace($typeClass, $graph) {
            $graph |=> GetDefaultNamespace
        }

        function ValidateTypeClass($typeClass) {
            $::.TypeProvider.ValidateTypeClass($this, $typeClass)
        }
    }
}
