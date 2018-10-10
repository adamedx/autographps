# Copyright 2018, Adam Edwards
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

    function __initialize($schemaData) {
        $this.SchemaData = $schemaData
        $this.namespace = $schemaData.Edmx.DataServices.Schema.Namespace
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
        $entityTypes = __InitializeTypesOnDemand $true
        if ( ! $entityTypes ) {
            $this.typeSchemas.values
        }
    }

    function GetComplexTypes($typeName) {
        if ( $typeName ) {
            $this.SchemaData.Edmx.DataServices.Schema.ComplexType | where Name -eq $typeName
        } else {
            $this.SchemaData.Edmx.DataServices.Schema.ComplexType
        }
    }

    function GetEntitySets {
        $::.ProgressWriter |=> WriteProgress -id 2 -activity "Parsing entity sets"
        $this.SchemaData.Edmx.DataServices.Schema.EntityContainer.EntitySet
    }

    function GetSingletons {
        $::.ProgressWriter |=> WriteProgress -id 2 -activity "Parsing singletons"
        $this.SchemaData.Edmx.DataServices.Schema.EntityContainer.Singleton
    }

    function GetActions {
        $::.ProgressWriter |=> WriteProgress -id 2 -activity "Parsing actions"
        $this.SchemaData.Edmx.DataServices.Schema.Action
    }

    function GetFunctions {
        $::.ProgressWriter |=> WriteProgress -id 2 -activity "Parsing functions"
        $this.SchemaData.Edmx.DataServices.Schema.Function
    }

    function __InitializeTypesOnDemand($returnNewTypes = $false) {
        if ( ! $this.typeSchemas ) {
            $::.ProgressWriter |=> WriteProgress -id 2 -activity "Parsing entity types"
            $typeSchemas = $this.SchemaData.Edmx.DataServices.Schema.EntityType
            $this.typeSchemas = @{}
            $typeSchemas | foreach {
                $qualifiedName = $this.namespace, $_.name -join '.'
                $this.typeSchemas.Add($qualifiedName, $_)
            }
            if ( $returnNewTypes ) {
                $typeSchemas
            }
        }
    }

    function __AddMethodBindingsFromMethodSchemas($methodSchemas) {
        $methodSchemas | foreach { $methodSchema = $_; $_.parameter | where name -eq bindingParameter | foreach { (__AddMethodBinding $_.type $methodSchema) } }
    }

    function __AddMethodBinding($typeName, $methodSchema) {
        if ( $this.methodBindings[$typeName] -eq $null ) {
            $this.methodBindings[$typeName] = @()
         }

        $this.methodBindings[$typeName] += $methodSchema
    }

}
