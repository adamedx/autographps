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
        write-host "Called updatevertex for '$($vertex.name)'"

        if ( ! (__IsVertexReady $vertex) ) {
            switch ( $vertex.entity.type ) {
                'Singleton' {
                    write-host "Singleton", $vertex.name, $vertex.entity.typedata.entitytypename
                    $vertex.buildstate.navigationsadded = $true
                    __AddTypeForVertex($vertex)

                    if ( ! $vertex.buildState.SingletonEntityTypeDataAdded ) {
                        __CopyTypeDataToSingleton $vertex
                    }
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                'EntityType' {
                    $name = $vertex.entity.typedata.entitytypename
                    if ( ! $vertex.buildstate.navigationsAdded ) {
                        __AddTypeEdges $name
                        $vertex.buildState.NavigationsAdded = $true
                    }

                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                'EntitySet' {
                    write-host "EntitySet", $vertex.name, $vertex.entity.typedata.entitytypename
                    $vertex.buildstate.navigationsadded = $true
                    __AddTypeForVertex($vertex)

                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                'Action' {
                    __AddTypeForVertex($vertex)
                    $vertex.buildState.NavigationsAdded = $true
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true

                }
                '__Scalar' {
                    __AddTypeForVertex($vertex)
                    $vertex.buildState.NavigationsAdded = $true
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                '__Root' {
                    __AddTypeForVertex($vertex)
                    $vertex.buildState.NavigationsAdded = $true
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                default {
                    throw "Unknown entity type $($vertex.entity.type) for entity name $($vertex.entity.name)"
                }
            }
            $vertex.buildState.SingletonEntityTypeDataAdded = $true
 #            $vertex.buildState.MethodEdgesAdded = $true
        }

#        $vertex.buildState.SingletonEntityTypeDataAdded = $true
 #       $vertex.buildState.NavigationsAdded = $true
#        $vertex.buildState.MethodEdgesAdded = $true
    }


    function __AddTypeForVertex($vertex) {
        $name = $vertex.entity.typedata.entitytypename
        $unqualifiedName = $name.substring($this.graph.namespace.length + 1, $name.length - $this.graph.namespace.length - 1)

        $typeVertex = $this.graph |=> TypeVertexFromTypeName $name

        if (! $typeVertex ) {
            __AddTypeVertex $vertex.entity.typedata.entitytypename
            $typeVertex = $this.graph |=> TypeVertexFromTypeName $name
        }

        $typeName = $typeVertex.entity.typedata.entitytypename
        if ( ! $typeVertex.buildState.NavigationsAdded ) {
            __AddTypeEdges $typeName
            $typeVertex.buildState.SingletonEntityTypeDataAdded = $true
            $typeVertex.buildState.NavigationsAdded = $true
        }
    }

    function __AddTypeVertex($name) {
        write-host "AddTypeVertex '$name'"
        $unqualifiedName = $name.substring($this.graph.namespace.length + 1, $name.length - $this.graph.namespace.length - 1)
        write-host $unqualifiedName

        $this.builder |=> __AddEntityTypeVertices $this.graph $unqualifiedName

        __AddTypeEdges $name

        $typeVertex = $this.graph |=> TypeVertexFromTypeName $name
        $typeVertex.buildstate.NavigationsAdded = $true
    }

    function __AddTypeEdges($qualifiedTypeName) {
        $typeVertex = $this.graph |=> TypeVertexFromTypeName $qualifiedTypeName
        $unqualifiedTypeName = $qualifiedTypeName.substring($this.graph.namespace.length + 1, $name.length - $this.graph.namespace.length - 1)
        write-host "AddEdges '$unqualifiedTypeName'"
        if ( ! $typeVertex.buildstate.navigationsAdded ) {
            $this.builder |=>  __AddEdgesToEntityTypeVertices $this.graph $unqualifiedTypeName
            $this.builder |=>  __AddMethodTransitionsByType $this.graph $qualifiedTypeName
#            $this.builder |=>  __ConnectEntityTypesWithMethodEdges $this.graph $qualifiedTypeName
#            $typeVertex.buildState.MethodEdgesAdded = $true
            $typeVertex.buildstate.NavigationsAdded = $true
        }
    }

    function __CopyTypeDataToSingleton($singletonVertex) {
        write-host "CopyTypeToSingleton '$($singletonVertex.name)'"
        $this.builder |=> __CopyEntityTypeEdgesToSingletons $this.graph $singletonVertex.name
    }

    function __IsVertexReady($vertex) {
        $vertex.buildState.SingletonEntityTypeDataAdded -and
        $vertex.buildState.NavigationsAdded  # -and
        # $vertex.buildState.MethodEdgesAdded
    }
}
