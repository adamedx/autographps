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

    function GetTypeDefinition($typeClass, $typeId) {
        if ( $typeClass -ne 'Entity' -and $typeClass -ne 'Complex' -and $typeClass -ne 'Unknown' ) {
            throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
        }

        $nativeSchema = GetNativeSchemaFromGraph $typeId $typeClass

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
                $typeInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $nativeSchema.namespace $propertySchema.Type
                $unaliasedPropertyTypeName = $this.base.graph |=> UnaliasQualifiedName $typeInfo.TypeFullName
                new-so TypeMember $propertySchema.Name $unaliasedPropertyTypeName $typeInfo.IsCollection Property $null $typeid
            }
        }

        $navigationProperties = if ( $nativeSchema.Schema | gm navigationproperty -erroraction ignore ) {
            foreach ( $navigationProperty in $nativeSchema.Schema.NavigationProperty ) {
                $navigationInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $nativeSchema.namespace $navigationproperty.Type
                $unaliasedNavigationPropertyTypeName = $this.base.graph |=> UnAliasQualifiedName $navigationInfo.TypeFullName
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
            $this.base.graph |=> UnAliasQualifiedName $nativeSchema.Schema.BaseType
        }

        new-so TypeDefinition $typeId $foundTypeClass $nativeSchema.Schema.name $nativeSchema.namespace $qualifiedBaseTypeName $properties $null $null $true $nativeSchema.Schema $navigationProperties $methods
    }

    function GetSortedTypeNames($typeClass) {
        $this.scriptclass |=> ValidateTypeClass $typeClass

        switch ( $typeClass ) {
            'Entity' {
                (GetEntityTypeSchemas).Keys
                break
            }
            'Complex' {
                (GetComplexTypeSchemas).Keys
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
            UpdateTypeTable $complexTypeTable $complexTypeSchemas
            $this.complexTypeTable = $complexTypeTable
        }

        $this.complexTypeTable
    }

    function GetEntityTypeSchemas {
        if ( ! $this.entityTypeTable ) {
            $entityTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $entityTypeSchemas = $this.base.graph |=> GetEntityTypes
            UpdateTypeTable $entityTypeTable $entityTypeSchemas
            $this.entityTypeTable = $entityTypeTable
        }

        $this.entityTypeTable
    }

    function GetMethodSchemasForType($qualifiedTypeName) {
        $methodSchemas = $this.base.graph |=> GetMethodsForType $qualifiedTypeName

        if ( $methodSchemas ) {
            $typeVertex = try {
                # We currently only do this because we don't have information about whether
                # the method is an action or function -- othewise, we could skip this step altogether.
                $this.base.graph |=> GetTypeVertex $qualifiedTypeName
            } catch {
                write-verbose "Methods found for type '$qualifiedTypeName', but no type exists -- discovery for non-entity types not yet implemented"
                return
            }

            foreach ( $methodSchema in $methodSchemas ) {
                $edge = $typeVertex.outgoingEdges[$methodSchema.name]

                if ( $edge -and $edge.transition.type -in 'Action', 'Function' ) {
                    $methodType = $edge.transition.type
                    [PSCustomObject] @{
                        MethodType = $methodType
                        NativeSchema = $methodSchema
                    }
                }
            }
        }
     }

    function UpdateTypeTable($typeTable, $typeSchemas) {
        foreach ( $schema in $typeSchemas ) {
            $qualifiedTypeName = $schema.QualifiedName
            $typeTable.Add($qualifiedTypeName.tolower(), $schema)
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
        $unaliasedTypeName = $this.base.graph |=> UnAliasQualifiedName $qualifiedTypeName
        $nativeSchema = if ( $typeClass -eq 'Entity' -or $typeClass -eq 'Unknown' ) {
            # Using try / catch here and below because erroractionpreference ignore / silentlyconitnue
            # are known not to work due to a defect fixed in PowerShell 7.0
            try {
                GetTypeByName Entity $unaliasedTypeName
            } catch {
            }
        }

        if ( ! $nativeSchema -and ( $typeClass -eq 'Complex' -or $typeClass -eq 'Unknown' ) ) {
            $nativeSchema = try {
                GetTypeByName Complex $unaliasedTypeName
            } catch {
            }
        }

        if ( ! $nativeSchema ) {
            throw "Schema for type '$qualifiedTypeName' unaliased as '$unaliasedTypeName' of type class '$typeClass' was not found in Graph '$($this.base.graph.ApiVersion)'"
        }

        $nativeSchema
    }

    function __UpdateTypeIndex($index, $schemas, $typeClass) {
        write-progress -id 1 -activity "Updating search index '$($index.IndexedField)' for type class '$typeClass'" -status 'In progress'
        foreach ( $typeId in $schemas.Keys ) {
            $nativeSchema = $schemas[$typeId]

            switch ( $index.IndexedField ) {
                'Name' {  $index |=> Add $typeId $typeId $typeClass }
                'Property' {
                    if ( $nativeSchema.Schema | gm property -erroraction ignore ) {
                        foreach ( $property in $nativeSchema.Schema.property ) {
                            $index |=> Add $property.Name $typeId $typeClass
                        }
                    }
                }
                'NavigationProperty' {
                    if ( $nativeSchema.Schema | gm navigationproperty -erroraction ignore ) {
                        foreach ( $navigationProperty in $nativeSchema.Schema.navigationproperty ) {
                            $index |=> Add $navigationProperty.Name $typeId $typeClass
                        }
                    }
                }
                'Method' {
                    $methodSchemas = GetMethodSchemasForType $typeId
                    if ( $methodSchemas ) {
                        write-progress -id 2 -activity "Updating search index 'method' for type '$typeId'" -status 'In progress'
                        foreach ( $nativeMethodSchema in $methodSchemas.NativeSchema ) {
                            $index |=> Add $nativeMethodSchema.Name $typeId $typeClass
                        }
                    }
                }
                default {
                    throw "Unknown field name '$($index.IndexedField)'"
                }
            }
        }
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
            $::.TypeProvider |=> ValidateTypeClass $this $typeClass
        }
    }
}
