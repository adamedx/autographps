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
    $graph = $null
    $definitions = $null
    $prototypes = $null
    $hasRequiredTypeDefinitions = $false
    $typeProviders = $null

    function __initialize($graphContext) {
        $this.graphContext = $graphContext
        $this.graph = $::.GraphManager |=> GetGraph $this.graphContext
        $this.definitions = @{}
        $this.prototypes = @{
            $false = @{}
            $true = @{}
        }
        $this.typeProviders = @{}
    }

    function GetPrototype($typeClass, $typeName, $fullyQualified = $false, $setDefaultValues = $false, $recursive = $false, $propertyFilter, [object[]] $valueList, $propertyList, $skipPropertyCheck) {
        $typeId = GetOptionallyQualifiedName $typeClass $typeName $fullyQualified
        $hasProperties = $propertyFilter -ne $null -or $propertyList -ne $null

        $prototype = if ( ! $hasProperties ) {
            GetPrototypeFromCache $typeId $typeClass $setDefaultValues $recursive
        }

        if ( $hasProperties -or ! ( HasCacheKey $typeId $setDefaultValues $recursive ) ) {
            if ( ! $prototype ) {
                $type = FindTypeDefinition $typeClass $typeId $true $true
                if ( ! $type ) {
                    throw 'anger'
                }
                $builder = new-so GraphObjectBuilder $this $type $setDefaultValues $recursive $propertyFilter $valueList $propertyList $skipPropertyCheck
                $prototype = $builder |=> ToObject
            }

            if ( ! $hasProperties ) {
                AddPrototypeToCache $typeId $type.Class $setDefaultValues $recursive $prototype
            }
        }
        [PSCustomObject] @{
            Type = $typeId
            ObjectProtoType = $prototype
        }
    }

    function FindTypeDefinition($typeClass, $typeName, $fullyQualified, $errorIfNotFound = $false) {
        $definition = $null

        $classesLeftToTry = 1

        $classes = if ( $typeClass -eq 'Unknown' ) {
            $orderedClasses = GetTypeClassPrecedence
            $classesLeftToTry = $orderedClasses.length
            $orderedClasses
        } else {
            [GraphTypeClass] $typeClass
        }

        foreach ( $class in $classes ) {
            $classesLeftToTry--

            $typeId = GetOptionallyQualifiedName $class $typeName $fullyQualified

            $definition = $this.definitions[$typeId]

            if ( ! $definition ) {
                try {
                    $definition = GetTypeDefinition $class $typeId
                } catch {
                    if ( $errorIfNotFound ) {
                        if ( $typeClass -eq 'Unknown' ) {
                            if ( $classesLeftToTry -eq 0 ) {
                                throw "Type '$typeId' could not be found for any type class in Graph '$($this.graph.ApiVersion)'"
                            }
                        } else {
                            throw
                        }
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

            $typeProvider = __GetTypeProvider $typeClass $this.graph
            $type = $typeProvider |=> GetTypeDefinition $typeClass $typeId

            $requiredTypes = @($type)

            $baseTypeId = $type.BaseType

            while ( $baseTypeId ) {
                $baseTypeProvider = __GetTypeProvider $typeClass $this.graph
                $baseType = $baseTypeProvider |=> GetTypeDefinition Unknown $baseTypeId

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

    enum PropertyType {
        Property
        NavigationProperty
    }

    function GetTypeDefinitionTransitiveProperties($typeDefinition, $propertyType = 'Property') {
        $properties = @()

        $validatedPropertyType = [PropertyType] $propertyType

        $propertyMember = if ( $validatedPropertyType -eq 'NavigationProperty' ) {
            'NavigationProperties'
        } else {
            'Properties'
        }

        if ( $typeDefinition.$propertyMember ) {
            $properties += $typeDefinition.$propertyMember
        }

        $visitedBaseTypes = @{}
        $baseTypeId = $typeDefinition.BaseType

        while ( $baseTypeId -and ! $visitedBaseTypes[$baseTypeId] ) {
            $visitedBaseTypes[$baseTypeId] = $true
            $baseTypeDefinition = FindTypeDefinition $typeDefinition.Class $baseTypeId $true
            if ( $baseTypeDefinition ) {
                $properties += $baseTypeDefinition.$PropertyMember
                $baseTypeId = $baseTypeDefinition.BaseType
            } else {
                $baseTypeId = $null
            }
        }

        $properties
    }

    function GetPrototypeId($typeId, $setDefaults, $recursive) {
        '{0}:{1}:{2}' -f $typeId, ([int32] $setDefaults), ([int32] $recursive)
    }

    function GetPrototypeFromCache($typeId, $typeClass, $setDefaults, $recursive) {
        $id = GetPrototypeId $typeId $setDefaults $recursive
        $cachedPrototype = $this.prototypes[$id]

        if ( $cachedPrototype ) {
            $foundTypeClass = $cachedPrototype['TypeClass']
            if ( $foundTypeClass -ne $typeClass ) {
                if ( $typeClass -ne 'Unknown' ) {
                    throw "Type '$typeId' was found with type class '$foundTypeClass' instead of required type class '$typeClass'"
                }
            }
            $cachedPrototype['Prototype']
        }
    }

    function AddPrototypeToCache($typeId, $typeClass, $setDefaults, $recursive, $prototype) {
        $id = GetPrototypeId $typeId $setDefaults $recursive
        $this.prototypes.add($id, @{Prototype=$prototype;TypeClass=$typeClass})
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
                GetTypeDefinition $_.typeClass $_.typeId $true | out-null
            }

            $this.hasRequiredTypeDefinitions = $true
        }
    }

    function GetTypeClassPrecedence {
        [GraphTypeClass]::Primitive, [GraphTypeClass]::Entity, [GraphTypeClass]::Complex, [GraphTypeClass]::Enumeration
    }

    function GetOptionallyQualifiedName($typeClass, $typeName, $isFullyQualified) {
        if ( $isFullyQualified ) {
            $this.graph |=> UnaliasQualifiedName $typeName
        } else {
            $typeNamespace = $::.TypeProvider |=> GetDefaultNamespace $typeClass $this.graph
            $::.TypeSchema |=> GetQualifiedTypeName $typeNamespace $typeName
        }
    }

    function __GetTypeProvider([GraphTypeClass] $typeClass) {
        $providerObjectClass = $::.TypeProvider |=> GetProviderForClass $typeClass
        __GetTypeProviderByObjectClass $providerObjectClass
    }

    function __GetTypeProviderByObjectClass($providerObjectClass) {
        $provider = $this.typeProviders[$providerObjectClass]
        if ( ! $provider ) {
            $provider = new-so $providerObjectClass $this.graph
            $this.typeProviders[$providerObjectClass] = $provider
        }
        $provider
    }

    static {
        function Get($graphContext) {
            $manager = $graphContext |=> GetState $::.GraphManager.TypeStateKey

            if ( ! $manager ) {
                $graph = $::.GraphManager |=> GetGraph $graphContext
                $manager = new-so TypeManager $graphContext
                $graphContext |=> AddState $::.GraphManager.TypeStateKey $manager
            }

            $manager
        }

        function GetSortedTypeNames($allowedTypeClasses, $graphContext) {
            $typeClasses = if ( $allowedTypeClasses -eq 'Unknown' ) {
                'Entity', 'Complex', 'Primitive', 'Enumeration'
            } else {
                , $allowedTypeClasses
            }

            $manager = Get $graphContext

            $typeNames = foreach ( $targetTypeClass in $typeClasses ) {
                $typeProvider = $manager |=> __GetTypeProvider $targetTypeClass
                $typeProvider |=> GetSortedTypeNames $targetTypeClass
            }

            $result = if ( $typeClasses.length -ne 1 ) {
                $typeNames
            } else {
                $typeNames | sort-object
            }

            $result
        }
    }
}

