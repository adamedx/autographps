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
. (import-script TypeDefinition)

ScriptClass CompositeTypeProvider {
    $base = $null
    $entityTypeTable = $null
    $complexTypeTable = $null

    function __initialize($graphContext) {
        $this.base = new-so TypeProvider $this $graphContext
    }

    function GetTypeDefinition($typeClass, $typeId) {
        if ( $typeClass -ne 'Entity' -and $typeClass -ne 'Complex' -and $typeClass -ne 'Unknown' ) {
            throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
        }

        $nativeSchema = GetNativeSchemaFromGraph $typeId $typeClass

        $properties = if ( $nativeSchema.Schema | gm property -erroraction ignore ) {
            foreach ( $propertySchema in $nativeSchema.Schema.Property ) {
                $typeInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $nativeSchema.namespace $propertySchema.Type
                new-so TypeProperty $propertySchema.Name $typeInfo.TypeFullName $typeInfo.IsCollection
            }
        }

        $navigationProperties = if ( $nativeSchema.Schema | gm navigationproperty -erroraction ignore ) {
            foreach ( $navigationProperty in $nativeSchema.Schema.NavigationProperty ) {
                $navigationInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $nativeSchema.namespace $navigationproperty.Type
                new-so TypeProperty $navigationproperty.Name $navigationInfo.TypeFullName $navigationInfo.IsCollection
            }
        }

        $qualifiedBaseTypeName  = if ( $nativeSchema.Schema | gm BaseType -erroraction ignore) {
            $this.base.graphDataModel |=> UnAliasQualifiedName $nativeSchema.Schema.BaseType
        }

        new-so TypeDefinition $typeId $typeClass $nativeSchema.Schema.name $nativeSchema.namespace $qualifiedBaseTypeName $properties $null $null $true $nativeSchema.Schema $navigationProperties
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

    function GetComplexTypeSchemas {
        if ( ! $this.complexTypeTable ) {
            $complexTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $complexTypeSchemas = $this.base.graphDataModel |=> GetComplexTypes
            UpdateTypeTable $complexTypeTable $complexTypeSchemas
            $this.complexTypeTable = $complexTypeTable
        }

        $this.complexTypeTable
    }

    function GetEntityTypeSchemas {
        if ( ! $this.entityTypeTable ) {
            $entityTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $entityTypeSchemas = $this.base.graphDataModel |=> GetEntityTypes
            UpdateTypeTable $entityTypeTable $entityTypeSchemas
            $this.entityTypeTable = $entityTypeTable
        }

        $this.entityTypeTable
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
        $unaliasedTypeName = $this.base.graphDataModel |=> UnAliasQualifiedName $qualifiedTypeName
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
            throw "Schema for type '$qualifiedTypeName' unaliased as '$unaliasedTypeName' of type class '$typeClass' was not found in Graph '$($this.base.graphContext.version)'"
        }

        $nativeSchema
    }

    static {
        function GetTypeProvider($graphContext) {
            $::.TypeProvider |=> GetTypeProvider $this $graphContext
        }

        function GetSupportedTypeClasses {
            @('Entity', 'Complex')
        }

        function GetDefaultNamespace($typeClass, $graphContext) {
            $::.TypeProvider |=> GetGraphNamespace $graphContext
        }

        function ValidateTypeClass($typeClass) {
            $::.TypeProvider |=> ValidateTypeClass $this $typeClass
        }
    }
}
