# Copyright 2019, Adam Edwards
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

ScriptClass GraphDataModel {
    $SchemaData = $null
    $methodBindings = $null
    $typeSchemas = $null
    $namespace = $null
    $namespaceAlias = $null
    $firstNamespaceMatch = $null
    $secondNamespaceMatch = $null

    function __initialize($schemaData) {
        $this.SchemaData = $schemaData
        $this.namespace = $schemaData.Edmx.DataServices.Schema.Namespace
        $this.namespaceAlias = if ( $schemaData.Edmx.DataServices.Schema | gm Alias -erroraction ignore ) {
            $schemaData.Edmx.DataServices.Schema.Alias
        }

        # Previously, the "Namespace" attribute of the Schema element was sufficient to determine
        # the fully qualified names of the types referenced in the rest of the schema. However, on
        # 2020-01-22, the metadata hosted by the Graph service was changed to include an Alias attribute
        # that allows use of the alias in a type name as a (typically shorter) synonym for the fully qualified
        # name of the type. That change regressed this code which was unaware of the "Alias" attribute.
        # The code below now accounts for it, though there is special handling in other parts of the code
        # to resolve aliases when resolving type names.
        # Note that namespace aliases are indeed legal and are documented for OData:
        # https://www.odata.org/documentation/odata-version-3-0/common-schema-definition-language-csdl/.

        $this.firstNamespaceMatch = $this.namespace + '.'
        if ( $this.namespaceAlias ) {
            if ( $this.namespace.length -gt $this.namespaceAlias.length ) {
                $this.secondNamespaceMatch = $this.namespaceAlias + '.'
            } else {
                $this.firstnamespaceMatch = $this.namespaceAlias + '.'
                $this.secondNamespaceMatch = $this.namespace + '.'
            }
        }
    }

    function GetNamespace {
        $this.SchemaData.Edmx.DataServices.Schema.Namespace
    }

    function GetEntityTypeByName($typeName) {
        __InitializeTypesOnDemand
        $this.typeSchemas[$typeName]
    }

    function GetMethodBindingsForType($typeName) {
        if ( $this.methodBindings -eq $null ) {
            $this.methodBindings = @{}
            $actions = GetActions
            __AddMethodBindingsFromMethodSchemas $actions

            $functions = GetFunctions
            __AddMethodBindingsFromMethodSchemas $functions
        }

        $this.methodBindings[$typeName]
    }

    function GetEntityTypes {
        __InitializeTypesOnDemand
        $this.typeSchemas.values
    }

    function GetComplexTypes($typeName) {
        if ( $typeName ) {
            $this.SchemaData.Edmx.DataServices.Schema.ComplexType | where Name -eq $typeName
        } else {
            $this.SchemaData.Edmx.DataServices.Schema.ComplexType
        }
    }

    function GetEntitySets {
        $::.ProgressWriter |=> WriteProgress -id 1 -activity "Reading entity sets"
        $this.SchemaData.Edmx.DataServices.Schema.EntityContainer.EntitySet
    }

    function GetSingletons {
        $::.ProgressWriter |=> WriteProgress -id 1 -activity "Reading singletons"
        $this.SchemaData.Edmx.DataServices.Schema.EntityContainer.Singleton
    }

    function GetActions {
        $::.ProgressWriter |=> WriteProgress -id 1 "Reading actions"
        $this.SchemaData.Edmx.DataServices.Schema.Action
    }

    function GetFunctions {
        $::.ProgressWriter |=> WriteProgress -id 1 "Reading functions"
        $this.SchemaData.Edmx.DataServices.Schema.Function
    }

    function UnqualifyTypeName($qualifiedTypeName, $onlyIfQualified) {
        $unqualified = if ( $qualifiedTypeName.Contains('.') ) {
            $qualifierLength = if ( $qualifiedTypeName.startswith($this.firstNamespaceMatch) ) {
                $this.firstNamespaceMatch.length
            } elseif ( $this.secondNamespaceMatch -and $qualifiedTypeName.startswith($this.secondNamespaceMatch) ) {
                $this.secondNamespaceMatch.length
            }

            if ( $qualifierLength -ne $null ) {
                $qualifiedTypeName.substring($qualifierLength)
            }
        }

        if ( $unqualified ) {
            $unqualified
        } elseif ( ! $onlyIfQualified ) {
            $qualifiedTypeName
        }
    }

    function UnaliasQualifiedName($name) {
        $unqualifiedName = UnqualifyTypeName $name $true
        $this.namespace, $unqualifiedName -join '.'
    }

    function __InitializeTypesOnDemand {
        if ( ! $this.typeSchemas ) {
            $::.ProgressWriter |=> WriteProgress -id 1 -activity "Reading entity types"
            $typeSchemas = $this.SchemaData.Edmx.DataServices.Schema.EntityType
            $this.typeSchemas = @{}
            $typeSchemas | foreach {
                $qualifiedName = $this.namespace, $_.name -join '.'
                $this.typeSchemas.Add($qualifiedName, $_)
            }

            $::.ProgressWriter |=> WriteProgress -id 1 -activity "Reading entity types" -completed
        }
    }

    function __AddMethodBindingsFromMethodSchemas($methodSchemas) {
        $methodSchemas | foreach { $methodSchema = $_; $_.parameter | where name -eq bindingParameter | foreach { (__AddMethodBinding $_.type $methodSchema) } }
    }

    function __AddMethodBinding($typeName, $methodSchema) {
        $unaliasedName = UnaliasQualifiedName $typeName
        if ( $this.methodBindings[$unaliasedName] -eq $null ) {
            $this.methodBindings[$unaliasedName] = @()
        }

        $this.methodBindings[$unaliasedName] += $methodSchema
    }
}
