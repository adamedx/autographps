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

. (import-script QualifiedSchema)

ScriptClass GraphDataModel {
    $apiMetadata = $null
    $apiModels = $null
    $aliases = $null
    $methodBindings = $null
    $typeSchemas = $null

    static {
        const DefaultNamespace 'microsoft.graph'
    }

    function __initialize($apiMetadata) {
        $this.apiMetadata = $apiMetadata
        $this.apiModels = @{}
        $this.aliases = @{}

        $apiMetadata.Edmx.DataServices.Schema | foreach {
            $schema = $_
            $namespace = $schema.Namespace

            if ( $this.apiModels[$namespace] ) {
                throw "Namespace '$namespace' already exists as a namespace or alias"
            }

            $alias = $null

            # For more information about namespace aliases, see the following OData documentation:
            # https://www.odata.org/documentation/odata-version-3-0/common-schema-definition-language-csdl/
            if ( $schema | gm Alias -erroraction ignore ) {
                $alias = $schema.alias
                if ( $this.aliases[$alias] -or $this.apiModels[$alias] ) {
                    throw "Alias '$alias' already exists as a namespace or alias"
                }
                $this.aliases.add($alias, $namespace)
            }

            $model = [PSCustomObject] @{
                Namespace = $namespace
                Alias = $alias
                Schema = $schema
            }

            $this.apiModels.add($namespace, $model)
        }
    }

    function GetDefaultNamespace {
        $this.scriptclass.DefaultNamespace
    }

    function GetNamespaces {
        $this.apiModels.keys
    }

    function GetSchema($namespace) {
        if ( ! $this.apiModels[$namespace] ) {
            throw "No model could be found for the specified namespace '$namespace'"
        }

        $this.apiModels[$namespace].Schema
    }

    function GetEntityTypeByName($typeName) {
        __InitializeTypesOnDemand
        $this.typeSchemas[$typeName]
    }

    function GetMethodBindingsForType($typeName) {
        if ( $this.methodBindings -eq $null ) {
            $this.methodBindings = @{}
            $actions = GetActions
            __AddMethodBindingsFromMethodSchemas $actions Action

            $functions = GetFunctions
            __AddMethodBindingsFromMethodSchemas $functions Function
        }

        $bindings = $this.methodBindings[$typeName]

        if ( $bindings ) {
            $bindings.Distinct.Values
        }
    }

    function GetEntityTypes {
        __InitializeTypesOnDemand
        $this.typeSchemas.Values
    }

    function GetComplexTypes($typeName) {
        Write-Progress -id 2 -activity "Reading complex types"
        foreach ( $model in $this.apiModels.Values ) {
            if ( $model.Schema | gm ComplexType -erroraction ignore ) {
                $complexTypeSchemas = if ( $typeName ) {
                    $model.Schema.ComplexType | where Name -eq $typeName
                } else {
                    $model.Schema.ComplexType
                }

                foreach ( $complexType in $complexTypeSchemas ) {
                    new-so QualifiedSchema ComplexType $model.namespace $complexType.name $complexType
                }
            }
        }
        Write-Progress -id 2 -activity "Reading complex types" -Completed
    }

    function GetEntitySets {
        Write-Progress -id 2 -activity "Reading entity sets"
        foreach ( $model in $this.apiModels.Values ) {
            if ( $model.Schema | gm EntityContainer -erroraction ignore ) {
                __QualifySchemaClass EntitySet $model.namespace $model.Schema.EntityContainer
            }
        }
        Write-Progress -id 2 -activity "Reading entity sets" -Completed
    }

    function GetSingletons {
        Write-Progress -id 2 -activity "Reading singletons"
        foreach ( $model in $this.apiModels.Values ) {
            if ( $model.Schema | gm EntityContainer -erroraction ignore ) {
                __QualifySchemaClass Singleton $model.namespace $model.Schema.EntityContainer
            }
        }
        Write-Progress -id 2 -activity "Reading singletons" -Completed
    }

    function GetEnumTypes {
        Write-Progress -id 2 -activity "Reading enumerated types"
        foreach ( $model in $this.apiModels.Values ) {
                __QualifySchemaClass EnumType $model.namespace $model.Schema
        }
        Write-Progress -id 2 -activity "Reading enumerated types" -Completed
    }

    function GetActions {
        Write-Progress -id 2 "Reading actions"
        foreach ( $model in $this.apiModels.Values ) {
            __QualifySchemaClass Action $model.namespace $model.Schema
        }
        Write-Progress -id 2 "Reading actions" -Completed
    }

    function GetFunctions {
        Write-Progress -id 2 "Reading functions"
        foreach ( $model in $this.apiModels.Values ) {
            __QualifySchemaClass Function $model.namespace $model.Schema
        }
        Write-Progress -id 2 "Reading functions" -Completed
    }

    function UnqualifyTypeName($qualifiedTypeName) {
        (ParseTypeName $qualifiedTypeName).UnqualifiedName
    }

    function ParseTypeName($qualifiedTypeName, $onlyIfQualified = $false) {
        $prefix = ''
        $namespace = $null
        $unqualified = if ( $qualifiedTypeName.Contains('.') ) {
            $lastElement = $null

            $qualifiedTypeName -split '\.' | foreach {
                $lastElement = $_
                if ( $prefix.length + 1 + $_.length -lt $qualifiedTypeName.length ) {
                    if ( $prefix.length -gt 0 ) {
                        $prefix += '.'
                    }
                    $prefix += "$_"
                }
            }

            if ( $this.apiModels[$prefix] ) {
                $namespace = $prefix
                $lastElement
            } elseif ( $this.aliases[$prefix] ) {
                $namespace = $this.aliases[$prefix]
                $lastElement
            }
        }

        $nameResult = if ( $unqualified ) {
            $unqualified
        } elseif ( ! $onlyIfQualified ) {
            $qualifiedTypeName
        }

        [PSCustomObject] @{
            Namespace = $namespace
            UnqualifiedName = $nameResult
        }
    }

    function UnaliasQualifiedName($name) {
        $nameInfo = ParseTypeName $name $true
        if ( $nameInfo.namespace ) {
            $nameInfo.namespace, $nameInfo.UnqualifiedName -join '.'
        } else {
            $name
        }
    }

    function GetNamespaceAlias($namespace) {
        $this.aliases[$namespace]
    }

    function __InitializeTypesOnDemand {
        if ( ! $this.typeSchemas ) {
            $this.typeSchemas = @{}
            Write-Progress -id 1 -activity "Reading entity types"
            foreach ( $model in $this.apiModels.Values ) {
                if ( $model.Schema | gm EntityType -erroraction ignore ) {
                    $typeSchemas = $model.Schema.EntityType
                    $typeSchemas | foreach {
                        $qualifiedSchema = new-so QualifiedSchema EntityType $model.namespace $_.name $_
                        $this.typeSchemas.Add($qualifiedSchema.qualifiedName, $qualifiedSchema)
                    }
                }
            }

            Write-Progress -id 1 -activity "Reading entity types" -completed
        }
    }

    function __QualifySchemaClass($schemaClass, $namespace, $schemaContainer) {
        if ( $schemaContainer | gm $schemaClass -erroraction ignore ) {
            foreach ( $schemaElement in $schemaContainer.$schemaClass ) {
                new-so QualifiedSchema $schemaClass $namespace $schemaElement.name $schemaElement
            }
        }
    }

    function __AddMethodBindingsFromMethodSchemas($methodSchemas, $methodType) {
        if ( $methodSchemas ) {
            # Assume that the first parameter is actually the binding parameter -- it is usually,
            # but not always, named 'bindingParameter'
            foreach ( $methodSchema in $methodSchemas ) {
                $nativeSchema = $methodSchema.Schema
                if ( ( $nativeSchema | gm parameter -erroraction ignore ) -and $nativeSchema.parameter) {
                    $bindingParameter = $nativeSchema.parameter | where name -eq 'bindingParameter' | select -first 1
                    if ( ! $bindingParameter ) {
                        $bindingParameter = $nativeSchema.parameter | select -first 1
                    }

                    if ( $bindingParameter ) {
                        __AddMethodBinding $bindingParameter.type $nativeSchema $methodType
                    }
                }
            }
        }
    }

    function __AddMethodBinding($typeName, $methodSchema, $methodType) {
        $unaliasedName = UnaliasQualifiedName $typeName
        if ( $this.methodBindings[$unaliasedName] -eq $null ) {
            $this.methodBindings[$unaliasedName] = @{Distinct=@{};All=@()}
        }

        # TODO: Understand this strange behavior seen in real metadata.
        # This covers a strange case -- it turns out that in 2021-02-22,
        # driveItem has not one, but two function elements for getactivitybyinterval.
        # The only difference is that one has no parameters, the other one does.
        # From documentation (https://docs.microsoft.com/en-us/graph/api/itemactivitystat-getactivitybyinterval?view=graph-rest-1.0&tabs=http),
        # there is nothing special about this function that would warrant such an odd
        # representation in the schema. The current theory is that the second instance,
        # which is the one that has the parameters, is the "real" instance, the first
        # is some strange schema generation artifact, possibly one that is ignored by
        # Microsoft Graph in some sort of "last writer wins" behavior.
        $this.methodBindings[$unaliasedName]['Distinct'][$methodSchema.Name] = @{Type=$methodType;Schema=$methodSchema}
        $this.methodBindings[$unaliasedName]['All'] += @{Type=$methodType;Schema=$methodSchema}
    }
}
