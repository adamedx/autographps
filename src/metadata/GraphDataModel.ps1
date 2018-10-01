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

    function __initialize($schemaData) {
        $this.SchemaData = $schemaData
    }

    function GetNamespace {
        $this.SchemaData.Edmx.DataServices.Schema.Namespace
    }

    function GetEntityTypes($typeName) {
        $::.ProgressWriter |=> WriteProgress -id 2 -activity "Parsing entity types"
        $result = if ( $typeName ) {
            $this.SchemaData.Edmx.DataServices.Schema.EntityType | where Name -eq $typeName
        } else {
            $this.SchemaData.Edmx.DataServices.Schema.EntityType
        }

#        if ( $typeName -and $result -and ( ( $result | select -expandproperty localname -erroraction silentlycontinue ) -eq $null ) ) {
#            $result | out-host
#        throw 'whoa2'
 #       }
        $result
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
}
