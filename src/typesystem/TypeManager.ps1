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
. (import-script TypeSchema)
. (import-script TypeProvider)
. (import-script ScalarTypeProvider)
. (import-script CompositeTypeProvider)
. (import-script TypeDefinition)
. (import-script GraphObjectBuilder)

ScriptClass TypeManager {
    . {}.module.newboundscriptblock($::.TypeSchema.EnumScript)

    $graphContext = $null
    $definitions = $null
    $prototypes = $null
    $hasRequiredTypeDefinitions = $false

    function __initialize($graphContext) {
        $this.graphContext = $graphContext
        $this.definitions = @{}
        $this.prototypes = @{
            $false = @{}
            $true = @{}
        }
    }

    function GetPrototype($typeClass, $typeName, $fullyQualified = $false, $setDefaultValues = $false, $recursive = $false, $propertyFilter, [object[]] $valueList, $propertyList, $skipPropertyCheck) {
        $typeId = GetOptionallyQualifiedName $typeClass $typeName $fullyQualified
        $hasProperties = $propertyFilter -ne $null -or $propertyList -ne $null

        $prototype = if ( ! $hasProperties ) {
            GetPrototypeFromCache $typeId $setDefaultValues $recursive
        }

        if ( $hasProperties -or ! ( HasCacheKey $typeId $setDefaultValues $recursive ) ) {
            if ( ! $prototype ) {
                $type = FindTypeDefinition $typeClass $typeId $true $true
                $builder = new-so GraphObjectBuilder $this $type $setDefaultValues $recursive $propertyFilter $valueList $propertyList $skipPropertyCheck
                $prototype = $builder |=> ToObject
            }

            if ( ! $hasProperties ) {
                AddPrototypeToCache $typeId $setDefaultValues $recursive $prototype
            }
        }
        [PSCustomObject] @{
            Type = $typeId
            ObjectProtoType = $prototype
        }
    }

    function FindTypeDefinition($typeClass, $typeName, $fullyQualified, $errorIfNotFound = $false) {
        $definition = $null

        $classes = if ( $typeClass -eq 'Unknown' ) {
            GetTypeClassPrecedence
        } else {
            [GraphTypeClass] $typeClass
        }

        foreach ( $class in $classes ) {
            $typeId = GetOptionallyQualifiedName $class $typeName $fullyQualified

            $definition = $this.definitions[$typeId]

            if ( ! $definition ) {
                try {
                    $definition = GetTypeDefinition $class $typeId
                } catch {
                    if ( $errorIfNotFound ) {
                        throw
                    }
                }
            }

            if ( $definition ) {
                break
            }
        }

        if ( $errorIfNotFound -and ! $definition ) {
            throw "Unable to find type '$typeId' of type class '$typeClass'"
        }

        $definition
    }

    function GetTypeDefinition($typeClass, $typeId, $skipRequiredTypes) {
        $definition = $this.definitions[$typeId]

        if ( ! $definition ) {
            if ( ! $skipRequiredTypes ) {
                InitializeRequiredTypes
            }

            $type = $::.TypeDefinition |=> Get $this.graphContext $typeClass $typeId

            $requiredTypes = @($type)

            $baseTypeId = $type.BaseType

            while ( $baseTypeId ) {
                $baseType = $::.TypeDefinition |=> Get $this.graphContext Unknown $baseTypeId
                $requiredTypes += $baseType

                $baseTypeId = if ( $baseType | gm BaseType -erroraction ignore ) {
                    $basetype.BaseType
                }
            }

            for ( $typeIndex = $requiredTypes.length - 1; $typeIndex -ge 0; $typeIndex-- ) {
                $requiredType = $requiredTypes[$typeIndex]
                $requiredTypeId = $requiredType.typeId
                if ( ! $this.definitions[$requiredTypeId] ) {
                    AddTypeDefinition $requiredTypeId $requiredType
                }
            }

            $definition = $this.definitions[$typeId]
        }

        $definition
    }

    function GetPrototypeId($typeId, $setDefaults, $recursive) {
        '{0}:{1}:{2}' -f $typeId, ([int32] $setDefaults), ([int32] $recursive)
    }

    function GetPrototypeFromCache($typeId, $setDefaults, $recursive) {
        $id = GetPrototypeId $typeId $setDefaults $recursive
        $this.prototypes[$id]
    }

    function AddPrototypeToCache($typeId, $setDefaults, $recursive, $prototype) {
        $id = GetPrototypeId $typeId $setDefaults $recursive
        $this.prototypes.add($id, $prototype)
    }

    function HasCacheKey($typeId, $setDefaults, $recursive) {
        $id = GetPrototypeId $typeId $setDefaults $recursive
        $this.prototypes.ContainsKey($id)
    }

    function AddTypeDefinition($typeId, $type) {
        if ( $this.definitions[$typeId] ) {
            throw "Type '$typeId' already exists"
        }

        $this.definitions.Add($typeId, $type)
    }

    function InitializeRequiredTypes {
        if ( ! $this.hasRequiredTypeDefinitions ) {
            $requiredTypeInfo = $::.TypeProvider |=> GetRequiredTypeInfo

            $requiredTypeInfo | foreach {
                GetTypeDefinition $requiredTypeInfo.typeClass $requiredTypeInfo.typeId $true | out-null
            }

            $this.hasRequiredTypeDefinitions = $true
        }
    }

    function GetTypeClassPrecedence {
        [GraphTypeClass]::Primitive, [GraphTypeClass]::Entity, [GraphTypeClass]::Complex, [GraphTypeClass]::Enumeration
    }

    function GetOptionallyQualifiedName($typeClass, $typeName, $isFullyQualified) {
        if ( $isFullyQualified ) {
            $graphDataModel = ($::.GraphManager |=> GetGraph $this.graphContext).builder.datamodel
            $graphDataModel |=> UnaliasQualifiedName $typeName
        } else {
            $typeNamespace = $::.TypeProvider |=> GetDefaultNamespace $typeClass $this.graphContext
            $::.TypeSchema |=> GetQualifiedTypeName $typeNamespace $typeName
        }
    }

    static {
        $managerByGraphContext = @{}

        function Get($graphContext) {
            $contextId = $graphContext |=> GetScriptObjectHashCode
            $manager = $this.managerByGraphContext[$contextId]

            if ( ! $manager ) {
                $manager = new-so TypeManager $graphContext
                $this.managerByGraphContext[$contextId] = $manager
            }

            $manager
        }

        function Clear($graphContext) {
            # TODO -- remove the static parts of this class and add the logic
            # to GraphManager which adds context to each Graph
            $contextId = $graphContext |=> GetScriptObjectHashCode
            $manager = $this.managerByGraphContext[$contextId]

            if ( $manager ) {
                # TODO -- similar issue here -- GraphManager should jsut
                # associate the type providers with the graph context
                $::.TypeProvider |=> RemoveTypeProvidersForGraph $graphContext
                $this.managerByGraphContext.Remove($contextId)
            }
        }
    }
}

