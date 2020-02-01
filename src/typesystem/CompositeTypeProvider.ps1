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
    $namespace = $null
    $entityTypeTable = $null
    $complexTypeTable = $null
    $namespaceAlias = $null

    function __initialize($graph) {
        $this.base = new-so TypeProvider $this $graph
        $this.namespace = $this.base.scriptclass |=> GetGraphNamespace $this.base.graph
        $this.namespaceAlias = (($::.GraphManager |=> GetGraph (gg -current).details).builder.dataModel).namespaceAlias
    }

    function GetTypeDefinition($typeClass, $typeId) {
        if ( $typeClass -ne 'Entity' -and $typeClass -ne 'Complex' -and $typeClass -ne 'Unknown' ) {
            throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
        }

        $nameInfo = $::.TypeSchema |=> GetTypeNameInfo $this.namespace $typeId

        $nativeSchema = GetNativeSchemaFromGraph $nameInfo.Name $typeClass

        $properties = if ( $nativeSchema | gm property -erroraction ignore ) {
            foreach ( $property in $nativeSchema.property ) {
                $typeInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $this.namespace $this.namespaceAlias $property.Type
                new-so TypeProperty $property.Name $typeInfo.TypeFullName $typeInfo.IsCollection
            }
        }

        $baseType = if ( $nativeSchema | gm BaseType -erroraction ignore) {
            $::.Entity |=> UnAliasQualifiedName $this.namespace $this.namespaceAlias $nativeSchema.baseType
        }

        new-so TypeDefinition $typeId $typeClass $nativeSchema.name $this.namespace $baseType $properties $null $null $true $nativeSchema
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
            $graphDataModel = ($::.GraphManager |=> GetGraph $this.base.graph).builder.dataModel
            $complexTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $complexTypeSchemas = $graphDataModel |=> GetComplexTypes
            UpdateTypeTable $complexTypeTable $complexTypeSchemas
            $this.complexTypeTable = $complexTypeTable
        }

        $this.complexTypeTable
    }

    function GetEntityTypeSchemas {
        if ( ! $this.entityTypeTable ) {
            $graphDataModel = ($::.GraphManager |=> GetGraph $this.base.graph).builder.dataModel
            $entityTypeTable = [System.Collections.Generic.SortedList[String, Object]]::new()
            $entityTypeSchemas = $graphDataModel |=> GetEntityTypes
            UpdateTypeTable $entityTypeTable $entityTypeSchemas
            $this.entityTypeTable = $entityTypeTable
        }

        $this.entityTypeTable
    }

    function UpdateTypeTable($typeTable, $typeSchemas) {
        foreach ( $schema in $typeSchemas ) {
            $qualifiedTypeName = $::.TypeSchema |=> GetQualifiedTypeName $this.namespace $schema.name
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

    function GetNativeSchemaFromGraph($unqualifiedTypeName, $typeClass) {
        $qualifiedTypeName = $::.TypeSchema |=> GetQualifiedTypeName $this.namespace $unqualifiedTypeName

        $nativeSchema = if ( $typeClass -eq 'Entity' -or $typeClass -eq 'Unknown' ) {
            # Using try / catch here and below because erroractionpreference ignore / silentlyconitnue
            # are known not to work due to a defect fixed in PowerShell 7.0
            try {
                GetTypeByName Entity $qualifiedTypeName
            } catch {
            }
        }

        if ( ! $nativeSchema -and ( $typeClass -eq 'Complex' -or $typeClass -eq 'Unknown' ) ) {
            $nativeSchema = try {
                GetTypeByName Complex $qualifiedTypeName
            } catch {
            }
        }

        if ( ! $nativeSchema ) {
            throw "Schema for type '$unqualifiedTypeName' of type class '$typeClass' was not found in Graph '$($this.base.graph.name)'"
        }

        $nativeSchema
    }

    static {
        function GetTypeProvider($graph) {
            $::.TypeProvider |=> GetTypeProvider $this $graph
        }

        function GetSupportedTypeClasses {
            @('Entity', 'Complex')
        }

        function GetDefaultNamespace($typeClass, $graph) {
            $::.TypeProvider |=> GetGraphNamespace $graph
        }

        function ValidateTypeClass($typeClass) {
            $::.TypeProvider |=> ValidateTypeClass $this $typeClass
        }
    }
}
