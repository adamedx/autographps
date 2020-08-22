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

. (import-script GraphDataModel)
. (import-script EntityEdge)
. (import-script EntityVertex)

enum BuildFlags {
    NavigationsProcessed = 1
    MethodsProcessed = 2
    CopiedToSingleton = 4
}

ScriptClass GraphBuilder {

    $graphEndpoint = $null
    $version = $null
    $dataModel = $null

    static {
        $AllBuildFlags = ([BuildFlags]::NavigationsProcessed) -bOR
        ([BuildFlags]::MethodsProcessed) -bOR
        ([BuildFlags]::CopiedToSingleton)
    }

    function __initialize($graphEndpoint, $version, $dataModel) {
        $this.graphEndpoint = $graphEndpoint
        $this.version = $version
        $this.dataModel = $dataModel
    }

    function InitializeGraph($graph) {
        $metadataActivity = "Building graph version '$($this.version)' for endpoint '$($this.graphEndpoint)'"
        $::.ProgressWriter |=> WriteProgress -id 1 -activity $metadataActivity

        __AddRootVertices $graph
    }

    function __AddEntityTypeVertex($graph, $typeName) {
        AddEntityTypeVertices $graph $typeName
    }

    function __AddRootVertices($graph) {
        $singletons = $this.dataModel |=> GetSingletons
        __AddVerticesFromSchemas $graph $singletons Singleton

        $entitySets = $this.dataModel |=> GetEntitySets
        __AddVerticesFromSchemas $graph $entitySets EntitySet
    }

    function __AddVerticesFromSchemas($graph, $schemas, $vertexType) {
        $schemas | foreach {
            if ( ! $_.namespace ) {
                throw "No namespace specified for schema '$($_.QualifiedName)' of vertex type '$vertexType'"
            }

            __AddVertex $graph $_.Schema $vertexType $_.namespace
        }
    }

    function __AddVertex($graph, $schema, $vertexType, $namespace, $namespaceAlias) {
        $entity = new-so Entity $schema $namespace
        $graph |=> AddVertex $entity
    }

    function AddEntityTypeVertices($graph, $qualifiedTypeName) {
        $entityType = $this.dataModel |=> GetEntityTypeByName $qualifiedTypeName
        $nameInfo = __GetNamespaceInfoFromQualifiedTypeName $qualifiedTypeName
        if ( $qualifiedTypeName -and $entityType -eq $null ) {
            throw "Type '$qualifiedTypeName' does not exist in the schema for the graph at endpoint '$($graph.endpoint)' with API version '$($graph.apiversion)'"
        }

        $::.ProgressWriter |=> WriteProgress -id 1 -activity "Adding type '$qualifiedTypeName'"

        __AddVerticesFromSchemas $graph $entityType EntityType
    }

    function __AddEdgesToEntityTypeVertex($graph, $sourceVertex) {
        if ( $sourceVertex.TestFlags([BuildFlags]::NavigationsProcessed) ) {
            return
        }

        $transitions = if ( $sourceVertex.entity.navigations ) {
            $sourceVertex.entity.navigations
        } else {
            @()
        }

        foreach ( $transition in $transitions ) {
            # Look for the existing type in the graph itself
            $unaliasedName = $this.dataModel |=> UnAliasQualifiedName $transition.typedata.typename
            $sink = $graph |=> TypeVertexFromTypeName $unaliasedName
            if ( ! $sink ) {
                # If we don't find the existing type, try to get it from the model instead
                $sinkSchema = $this.dataModel |=> GetEntityTypeByName $unAliasedName
                if ( $sinkSchema ) {
                    # We've found the type, now add it to the graph
                    __AddEntityTypeVertex $graph $unaliasedName
                    $sink = $graph |=> TypeVertexFromTypeName $unaliasedName
                } else {
                    write-verbose "Unable to find schema for '$($transition.type)', $($transition.typedata.typename)"
                }
            }

            if ( $sink ) {
                $edge = new-so EntityEdge $sourceVertex $sink $transition
                $sourceVertex |=> AddEdge $edge
            } else {
                write-verbose "Unable to find entity type for '$($transition.type)', $($transition.typedata.typename) = '$unaliasedName', skipping"
            }
        }

        $sourceVertex.SetFlags([BuildFlags]::NavigationsProcessed)
    }

    function AddEdgesToVertex($graph, $vertex, $skipIfExist) {
        if ( $vertex.TestFlags($::.GraphBuilder.AllBuildFlags) ) {
            if ( !$skipIfExist ) {
                throw "Vertex '$($vertex.name)' already has edges"
            }
            return
        }

        $qualifiedTypeName = $vertex.entity.typedata.typename
        $unqualifiedTypeName = $this.dataModel |=> UnqualifyTypeName $qualifiedTypeName
        $::.ProgressWriter |=> WriteProgress -id 1 -activity "Adding edges for '$($vertex.name)'"

        __AddEdgesToEntityTypeVertex $graph $vertex

        if ( $vertex.entity.type -ne 'Singleton' ) {
            __AddMethodTransitionsToVertex $graph $vertex
        } else {
            __CopyEntityTypeEdgesToSingletonVertex $graph $vertex
        }
    }

    function __CopyEntityTypeEdgesToSingletonVertex($graph, $source) {
        if ( $source.TestFlags([BuildFlags]::CopiedToSingleton) ) {
            throw "Data from type already copied to singleton '$($source.name)'"
        }

        $entityName = ($source.entity.typeData).TypeName
        $typeVertex = $graph |=> TypeVertexFromTypeName $entityName

        if ( $typeVertex -eq $null ) {
            throw "Unable to find an entity type for singleton '$($_.name)' and '$entityName'"
        }

        AddEdgesToVertex $graph $typeVertex $true

        $edges = $typeVertex.outgoingEdges.values | foreach {
            if ( ( $_ | gm transition ) -ne $null ) {
                $_
            }
        }

        $edges | foreach {
            $sink = $_.sink
            $transition = $_.transition
            $edge = new-so EntityEdge $source $sink $transition
            $source |=> AddEdge $edge
        }

        $source.SetFlags([BuildFlags]::CopiedToSingleton)
    }

    function __AddMethodTransitionsToVertex($graph, $sourceVertex) {
        if ( $sourceVertex.TestFlags([BuildFlags]::MethodsProcessed) ) {
            write-verbose "Methods already processed for $($sourceVertex.name), skipping method addition"
            return
        }

        $sourceTypeName = $sourceVertex.entity.typeData.TypeName
        $methods = $this.dataModel |=> GetMethodBindingsForType $sourceTypeName

        if ( ! $methods ) {
            write-verbose "Vertex ($sourceVertex.name) has no methods, skipping method addition"
            return
        }

        $methods | foreach {
            $method = $_
            $sink = if ( $method | gm ReturnType ) {
                $typeName = $method.ReturnType | select -expandproperty Type

                $typeVertex = $graph |=> TypeVertexFromTypeName $typeName

                if ( $typeVertex -eq $null ) {
                    try {
                        __AddEntityTypeVertex $graph $typeName
                        $typeVertex = $graph |=> TypeVertexFromTypeName $typeName
                    } catch {
                            # Possibly an enumeration type, this will just be considered a scalar
                    }
                }

                if ( $typeVertex ) {
                    $typeVertex
                } else {
                    write-verbose "Type $($typeName) returned by $($method.name) cannot be found, configuring Scalar vertex"
                    $::.EntityVertex.ScalarVertex
                }
            } else {
                $::.Entityvertex.NullVertex
            }
            __AddMethod $sourceVertex $method $sink
        }
        $sourceVertex.SetFlags([BuildFlags]::MethodsProcessed)
    }

    function __AddMethod($targetVertex, $methodSchema, $returnTypeVertex) {
        if ( ! ($targetVertex |=> EdgeExists($methodSchema.name)) ) {
            $nameInfo = __GetNamespaceInfoFromQualifiedTypeName $targetVertex.typeName
            $methodEntity = new-so Entity $methodSchema $nameInfo.Namespace
            $edge = new-so EntityEdge $targetVertex $returnTypeVertex $methodEntity
            $targetVertex |=> AddEdge $edge
        } else {
            write-verbose "Skipped add of edge $($methodSchema.name) to $($returnTypeVertex.id) from vertex $($targetVertex.id) because it already exists."
        }
    }

    function __GetNamespaceInfoFromQualifiedTypeName($qualifiedTypeName) {
        $nameInfo = $this.dataModel |=> ParseTypeName $qualifiedTypeName $true
        [PSCustomObject] @{
            Namespace = $nameInfo.Namespace
            NamespaceAlias = $this.dataModel |=> GetNamespaceAlias $nameInfo.namespace
        }
    }
}

