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
        Write-Progress -id 2 -activity $metadataActivity -ParentId 1

        __AddRootVertices $graph

        Write-Progress -id 2 -activity $metadataActivity -Completed -ParentId 1
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
        $graph.AddVertex($entity)
    }

    function AddEntityTypeVertices($graph, $qualifiedTypeName) {
        $entityType = $this.dataModel.GetEntityTypeByName($qualifiedTypeName)

        if ( $qualifiedTypeName -and $entityType -eq $null ) {
            throw "Type '$qualifiedTypeName' does not exist in the schema for the graph at endpoint '$($graph.endpoint)' with API version '$($graph.apiversion)'"
        }

        Write-Progress -id 1 -activity "Adding type '$qualifiedTypeName'"

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
            $unaliasedName = $this.dataModel.UnAliasQualifiedName($transition.typedata.typename)
            $sink = $graph.TypeVertexFromTypeName($unaliasedName)
            if ( ! $sink ) {
                # If we don't find the existing type, try to get it from the model instead
                $sinkSchema = $this.dataModel.GetEntityTypeByName($unAliasedName)
                if ( $sinkSchema ) {
                    # We've found the type, now add it to the graph
                    __AddEntityTypeVertex $graph $unaliasedName
                    $sink = $graph.TypeVertexFromTypeName($unaliasedName)
                } else {
                    write-verbose "Unable to find schema for '$($transition.type)', $($transition.typedata.typename)"
                }
            }

            if ( $sink ) {
                $edge = new-so EntityEdge $sourceVertex $sink $transition
                $sourceVertex.AddEdge($edge)
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
        $unqualifiedTypeName = $this.dataModel.UnqualifyTypeName($qualifiedTypeName)
        Write-Progress -id 1 -activity "Adding edges for '$($vertex.name)'"

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
        $typeVertex = $graph.TypeVertexFromTypeName($entityName)

        if ( $typeVertex -eq $null ) {
            throw "Unable to find an entity type for singleton '$($_.name)' and '$entityName'"
        }

        AddEdgesToVertex $graph $typeVertex $true

        $edges = $typeVertex.outgoingEdges.values | foreach {
            if ( ( $_ | gm transition -erroraction ignore ) -ne $null ) {
                $_
            }
        }

        $edges | foreach {
            $sink = $_.sink
            $transition = $_.transition
            $edge = new-so EntityEdge $source $sink $transition
            $source.AddEdge($edge)
        }

        $source.SetFlags([BuildFlags]::CopiedToSingleton)
    }

    function __AddMethodTransitionsToVertex($graph, $sourceVertex) {
        if ( $sourceVertex.TestFlags([BuildFlags]::MethodsProcessed) ) {
            write-verbose "Methods already processed for $($sourceVertex.name), skipping method addition"
            return
        }

        $sourceTypeName = $sourceVertex.entity.typeData.TypeName
        $methodBindings = $this.dataModel.GetMethodBindingsForType($sourceTypeName)

        if ( ! $methodBindings ) {
            write-verbose "Vertex ($sourceVertex.name) has no methods, skipping method addition"
            return
        }

        $methodBindings.Schema | foreach {
            $method = $_
            $sink = if ( $method | gm ReturnType ) {
                # If there's a return type, it can actually be of any type, not just an entity
                # type. We'll link this to a vertex for the entity type if it's an entity type, but
                # if the return type is not an entity, we'll just link it to a single "scalar" vertex,
                # or the null vertex if there is no return type.
                $typeName = $method.ReturnType | select -expandproperty Type
                $parsedName = $::.GraphUtilities.ParseTypeName($typeName)
                $unaliasedName = $this.dataModel.UnAliasQualifiedName($parsedName.TypeName)

                # This only returns vertices (i.e. entity types) that have already been seen,
                # so we may not find it.
                $typeVertex = $graph.TypeVertexFromTypeName($unaliasedName)

                if ( $typeVertex -eq $null ) {
                    # If the return type is not found, then see if such an entity type exists.
                    # If it doesn't, that means the return type is not an entity, i.e.
                    # it is a primitive, enumeration, or complex type. In this context,
                    # we will treat these as "scalar" types -- they are not traversable.
                    if ( $this.dataModel.GetEntityTypeByName($unaliasedName) ) {
                        try {
                            __AddEntityTypeVertex $graph $unaliasedName
                            $typeVertex = $graph.TypeVertexFromTypeName($unaliasedName)
                        } catch {
                            # The scheme is malformed such that even though the return type
                            # is listed in the schema, we could find no vertex. Move on from
                            # this procesing error, future attempts to traverse the return
                            # type will not succeeds.
                        }
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
        if ( ! ($targetVertex.EdgeExists($methodSchema.name)) ) {
            $nameInfo = __GetNamespaceInfoFromQualifiedTypeName $targetVertex.typeName
            $methodEntity = new-so Entity $methodSchema $nameInfo.Namespace
            $edge = new-so EntityEdge $targetVertex $returnTypeVertex $methodEntity
            $targetVertex.AddEdge($edge)
        } else {
            write-verbose "Skipped add of edge $($methodSchema.name) to $($returnTypeVertex.id) from vertex $($targetVertex.id) because it already exists."
        }
    }

    function __GetNamespaceInfoFromQualifiedTypeName($qualifiedTypeName) {
        $nameInfo = $this.dataModel.ParseTypeName($qualifiedTypeName, $true)
        $namespaceAlias = if ( $nameInfo.Namespace ) {
            $this.dataModel.GetNamespaceAlias($nameInfo.namespace)
        }
        [PSCustomObject] @{
            Namespace = $nameInfo.Namespace
            NamespaceAlias = $namespaceAlias
        }
    }
}

