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

. (import-script GraphBuilder)

ScriptClass DynamicBuilder {
    $builder = $null
    $graph = $null

    function __initialize($graph, $graphEndpoint, $version, $dataModel) {
        $this.graph = $graph
        $this.builder = new-so GraphBuilder $graphEndpoint $version $datamodel
    }

    function InitializeGraph {
        $this.builder |=> InitializeGraph $this.graph
    }

    function GetTypeVertex($qualifiedTypeName, $parent, $includeSinks) {
        $vertex = $this.graph |=> TypeVertexFromTypeName $qualifiedTypeName

        if ( ! $vertex ) {
            __AddTypeVertex $qualifiedTypeName
            $vertex = $this.graph |=> TypeVertexFromTypeName $qualifiedTypeName
        }

        if ( ! $vertex ) {
            throw "Vertex '$qualifiedTypeName' not found"
        }

        UpdateVertex $vertex $parent $includeSinks

        $vertex
    }

    function UpdateVertex($vertex, $parent, $includeSinks) {
        if ( ! (__IsVertexReady $vertex) ) {
            switch ( $vertex.entity.type ) {
                'Singleton' {
                    __AddTypeVertex $vertex.entity.typedata.entitytypename
                    __AddTypeForVertex $vertex
                }
                'EntityType' {
                    __AddTypeForVertex $vertex
                }
                'EntitySet' {
                    __AddTypeVertex $vertex.entity.typedata.entitytypename
                    __AddTypeForVertex $vertex
                }
                'Action' {
                    __AddTypeForVertex($vertex)
                }
                '__Scalar' {
                    __AddTypeForVertex($vertex)
                }
                '__Root' {
                    __AddTypeForVertex($vertex)
                }
                default {
                    throw "Unknown entity type $($vertex.entity.type) for entity name $($vertex.entity.name)"
                }
            }
        }
    }

    function __AddTypeForVertex($vertex) {
        $this.builder |=> __AddEdgesToVertex $this.graph $vertex $true
    }

    function __AddTypeVertex($qualifiedTypeName) {
        $vertex = $this.graph |=> TypeVertexFromTypeName $qualifiedTypeName
        if ( ! $vertex ) {
            $unqualifiedName = $qualifiedTypeName.substring($this.graph.namespace.length + 1, $qualifiedTypeName.length - $this.graph.namespace.length - 1)
            $this.builder |=> __AddEntityTypeVertices $this.graph $unqualifiedName
        }
    }

    function __CopyTypeDataToSingleton($singletonVertex) {
        $this.builder |=> __CopyEntityTypeEdgesToSingletonVertex $this.graph $singletonVertex
    }

    function __IsVertexReady($vertex) {
        $vertex.TestFlags($::.GraphBuilder.AllBuildFlags) -eq $::.GraphBuilder.AllBuildFlags
    }
}
