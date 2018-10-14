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

. (import-script Entity)
. (import-script EntityVertex)
. (import-script EntityEdge)

ScriptClass EntityGraph {
    $ApiVersion = $null
    $Endpoint = $null
    $vertices = $null
    $rootVertices = $null
    $typeVertices = $null
    $namespace = $null
    $schema = $null
    $builder = $null

    function __initialize( $namespace, $apiVersion = 'localtest', [Uri] $endpoint = 'http://localhost', $schemadata ) {
        $this.vertices = @{}
        $this.rootVertices = @{}
        $this.typeVertices = @{}
        $this.ApiVersion = $apiVersion
        $this.Endpoint = $endpoint
        $this.namespace = $namespace
        $this.schema = $schemadata
    }

    function GetSchema {
        $this.schema
    }

    function GetRootVertices {
        $this.rootVertices
    }

    function AddVertex($entity) {
        $vertex = new-so EntityVertex $entity
        $this.vertices.Add($vertex.id, $vertex)
        if ( $vertex.type -eq 'EntityType' ) {
            $this.typeVertices.Add(($vertex.typeName), $vertex)
        } elseif ( $vertex.type -eq 'EntitySet' -or $vertex.type -eq 'Singleton' ) {
            $this.rootVertices.Add($vertex.name, $vertex)
        }
    }

    function TypeVertexFromTypeName($typeName) {
        $typeData = $::.Entity |=> GetEntityTypeDataFromTypeName $typeName

        $this.typeVertices[$typeData.EntityTypeName]
    }

    static {
        $nullVertex = new-so EntityVertex $null
    }
}
