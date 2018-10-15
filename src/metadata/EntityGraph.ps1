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
. (import-script GraphBuilder)

ScriptClass EntityGraph {
    $ApiVersion = $null
    $Endpoint = $null
    $vertices = $null
    $rootVertices = $null
    $typeVertices = $null
    $namespace = $null
    $builder = $null

    function __initialize( $namespace, $apiVersion = 'localtest', [Uri] $endpoint = 'http://localhost', $dataModel ) {
        $this.vertices = @{}
        $this.rootVertices = @{}
        $this.typeVertices = @{}
        $this.ApiVersion = $apiVersion
        $this.Endpoint = $endpoint
        $this.namespace = $namespace
        $this.builder = new-so GraphBuilder $endpoint $apiVersion $dataModel
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

    function GetTypeVertex($qualifiedTypeName) {
        $vertex = TypeVertexFromTypeName $qualifiedTypeName

        if ( ! $vertex ) {
            __AddTypeVertex $qualifiedTypeName
            $vertex = TypeVertexFromTypeName $qualifiedTypeName
        }

        if ( ! $vertex ) {
            throw "Vertex '$qualifiedTypeName' not found"
        }

        __UpdateVertex $vertex

        $vertex
    }

    function GetVertexEdges($vertex) {
        __UpdateVertex $vertex
        $vertex.outgoingEdges
    }

    function __UpdateVertex($vertex) {
        if ( ! (__IsVertexComplete $vertex) ) {
            $::.ProgressWriter |=> WriteProgress -id 1 -activity "Update vertex '$($vertex.name)'"
            if ( $vertex.entity.type -eq 'Singleton' -or $vertex.entity.type -eq 'EntitySet' ) {
                __AddTypeVertex $vertex.entity.typedata.entitytypename
            }
            __AddTypeForVertex $vertex
            $::.ProgressWriter |=> WriteProgress -id 1 -activity "Vertex '$($vertex.name)' successfully update" -completed
        }
    }

    function __AddTypeForVertex($vertex) {
        $this.builder |=> AddEdgesToVertex $this $vertex $true
    }

    function __AddTypeVertex($qualifiedTypeName) {
        $vertex = TypeVertexFromTypeName $qualifiedTypeName
        if ( ! $vertex ) {
            $unqualifiedName = $qualifiedTypeName.substring($this.namespace.length + 1, $qualifiedTypeName.length - $this.namespace.length - 1)
            $this.builder |=> AddEntityTypeVertices $this $unqualifiedName
        }
    }

    function __IsVertexComplete($vertex) {
        $vertex.TestFlags($::.GraphBuilder.AllBuildFlags) -eq $::.GraphBuilder.AllBuildFlags
    }

    static {
        $nullVertex = new-so EntityVertex $null

        function NewGraph($endpoint, $version, $schemadata) {
            $dataModel = new-so GraphDataModel $schemadata
            $graph = new-so EntityGraph ($dataModel |=> GetNamespace) $version $Endpoint $dataModel

            $graph.builder |=> InitializeGraph $graph

            $graph
        }
    }
}
