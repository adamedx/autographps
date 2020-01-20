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

    function __initialize($graph) {
        $this.base = new-so TypeProvider $this $graph
    }

    function GetTypeDefinition($typeClass, $typeId) {
        if ( $typeClass -ne 'Entity' -and $typeClass -ne 'Complex' -and $typeClass -ne 'Unknown' ) {
            throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
        }

        $namespace = $this.base.scriptclass |=> GetGraphNamespace $this.base.graph

        $nameInfo = $::.TypeSchema |=> GetTypeNameInfo $namespace $typeId

        $nativeSchema = GetNativeSchemaFromGraph $namespace $nameInfo.Name $typeClass

        $members = if ( $nativeSchema | gm property -erroraction ignore ) {
            foreach ( $property in $nativeSchema.property ) {
                $typeInfo = GetNormalizedPropertyTypeInfo $property.Type
                new-so TypeMember $property.Name $typeInfo.TypeFullName $typeInfo.IsCollection
            }
        }

        $baseType = if ( $nativeSchema | gm BaseType -erroraction ignore) {
            $nativeSchema.baseType
        }

        new-so TypeDefinition $typeId $typeClass $nativeSchema.name $namespace $baseType $members $null $null $true $nativeSchema
    }

    function GetNativeSchemaFromGraph($namespace, $unqualifiedTypeName, $typeClass) {
        $graphDataModel = ($::.GraphManager |=> GetGraph $this.base.graph).builder.dataModel

        $nativeSchema = if ( $typeClass -eq 'Entity' -or $typeClass -eq 'Unknown' ) {
            $qualifiedTypeName = $::.TypeSchema |=> GetQualifiedTypeName $namespace $unqualifiedTypeName
            # Using try / catch here and below because erroractionpreference ignore / silentlyconitnue
            # are known not to work due to a defect fixed in PowerShell 7.0
            try {
                $graphDataModel |=> GetEntityTypeByName $qualifiedTypeName
            } catch {
            }
        }

        if ( ! $nativeSchema -and ( $typeClass -eq 'Complex' -or $typeClass -eq 'Unknown' ) ) {
            $nativeSchema = try {
                $graphDataModel |=> GetComplexTypes $unqualifiedTypeName
            } catch {
            }
        }

        if ( ! $nativeSchema ) {
            throw "Schema for type '$unqualifiedTypeName' of type class '$typeClass' was not found in Graph '$($this.base.graph.name)'"
        }

        $nativeSchema
    }

    function GetNormalizedPropertyTypeInfo($typeSpec) {
        $isCollection = $false
        $typeName = if ($typeSpec -match 'Collection\((?<typename>.+)\)') {
            $isCollection = $true
            $matches.typename
        } else {
            $typeSpec
        }

        [PSCustomObject] @{
            TypeFullName = $typeName
            IsCollection = $isCollection
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
            $::.TypeProvider |=> GetGraphNamespace $graph
        }

        function ValidateTypeClass($typeClass) {
            $::.TypeProvider |=> ValidateTypeClass $this $typeClass
        }
    }
}
