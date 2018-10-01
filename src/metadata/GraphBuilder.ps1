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

. (import-script GraphDataModel)
. (import-script EntityEdge)
. (import-script EntityVertex)
. (import-script EntityGraph)

enum BuildFlags {
    NavigationsProcessed = 1
    MethodsProcessed = 2
    CopiedToSingleton = 4
}

ScriptClass GraphBuilder {

    $graphEndpoint = $null
    $version = $null
    $dataModel = $null
    $namespace = $null
    $percentComplete = 0
    $dataModel = $null
    $deferredBuild = $false

    static {
        $AllBuildFlags = ([BuildFlags]::NavigationsProcessed) -bOR
        ([BuildFlags]::MethodsProcessed) -bOR
        ([BuildFlags]::CopiedToSingleton)
    }

    function __initialize($graphEndpoint, $version, $dataModel, $deferredBuild) {
        $this.graphEndpoint = $graphEndpoint
        $this.version = $version
        $this.dataModel = $dataModel
        $this.namespace = $this.dataModel |=> GetNamespace
        $this.deferredBuild = $deferredBuild
    }

    function InitializeGraph($graph) {
        __UpdateProgress 0

        __AddRootVertices $graph

        __AddMethodBindings $graph

        __AddEntityTypeSchemas $graph

#        __AddEntitytypeVertices $graph

#         __AddEdgesToEntityTypeVertices $graph

#        __ConnectEntityTypesWithMethodEdges $graph
#        __AddMethodTransitionsByType $graph
#        __CopyEntityTypeEdgesToSingletons $graph

        __UpdateProgress 100
    }

    function __AddEntityTypeVertex($graph, $typeName) {
        __AddEntityTypeVertices $graph $typeName
    }

    function __AddRootVertices($graph) {
        $singletons = $this.dataModel |=> GetSingletons
        __AddVerticesFromSchemas $graph $singletons

        $entitySets = $this.dataModel |=> GetEntitySets
        __AddVerticesFromSchemas $graph $entitySets
    }

    function __AddEntityTypeSchemas($graph) {
        $entityTypes = $this.dataModel |=> GetEntityTypes

        $entityTypes | foreach {
            $graph |=> AddEntityTypeSchema $_.name $_
        }
    }

    function __AddMethodBindings($graph) {
        $actions = $this.dataModel |=> GetActions
        __AddMethodBindingsFromMethodSchemas $graph $actions

        $functions = $this.dataModel |=> GetFunctions
        __AddMethodBindingsFromMethodSchemas $graph $functions
    }

    function __AddMethodBindingsFromMethodSchemas($graph, $methodSchemas) {
        $methodSchemas | foreach { $methodSchema = $_; $_.parameter | where name -eq bindingParameter | foreach { $graph.AddMethodBinding($_.type, $methodSchema) } }
    }

    function __AddVerticesFromSchemas($graph, $schemas) {
        $schemas | foreach {
            __AddVertex $graph $_
        }
    }

    function __AddVertex($graph, $schema) {
        $entity = new-so Entity $schema $this.namespace
        $graph |=> AddVertex $entity
    }

    function __AddEntityTypeVertices($graph, $unqualifiedTypeName) {
#        $entityTypes = $this.dataModel |=> GetEntityTypes $unqualifiedTypeName

        $qualifiedTypeName = $graph.namespace, $unqualifiedName -join '.'
        $entityTypes = $graph |=> GetEntityTypeSchema $qualifiedTypeName
        if ( $unqualifiedTypeName -and $entityTypes -eq $null ) {
            throw "Type '$unqualifiedTypeName' does not exist in the schema for the graph at endpoint '$($graph.endpoint)' with API version '$($graph.apiversion)'"
        }

        __AddVerticesFromSchemas $graph $entityTypes
    }

    function __AddEdgesToEntityTypeVertex($graph, $sourceVertex) {
        if ( $sourceVertex.TestFlags([BuildFlags]::NavigationsProcessed) ) {
            return
        }

        $source = $_
        $transitions = if ( $sourceVertex.entity.navigations ) {
            $sourceVertex.entity.navigations
        } else {
            @()
        }

        $transitions | foreach {
            $transition = $_
            $sink = $graph |=> TypeVertexFromTypeName $transition.typedata.entitytypename

            if ( ! $sink ) {
                $name = $transition.typedata.entitytypename
                $unqualifiedName = $name.substring($graph.namespace.length + 1, $name.length - $graph.namespace.length - 1)
                $sinkSchema = $this.datamodel |=> GetEntityTypes $unqualifiedName
                if ( $sinkSchema ) {
                    __AddEntityTypeVertex $graph $unqualifiedName
#                    __AddEntityTypeVertices $graph $unqualifiedName
                    $sink = $graph |=> TypeVertexFromTypeName $transition.typedata.entitytypename
                } else {
                    write-verbose "Unable to find schema for '$($transition.type)', $($transition.typedata.entitytypename)"
                }
            }

            if ( $sink ) {
                $edge = new-so EntityEdge $sourceVertex $sink $transition
                $sourceVertex |=> AddEdge $edge
            } else {
                write-verbose "Unable to find entity type for '$($transition.type)', $($transition.typedata.entitytypename), skipping"
            }
        }

        $sourceVertex.SetFlags([BuildFlags]::NavigationsProcessed)
    }

    function __AddEdgesToVertex($graph, $vertex, $skipIfExist) {
        if ( $vertex.TestFlags($::.GraphBuilder.AllBuildFlags) ) {
            if ( !$skipIfExist ) {
                throw "Vertex '$($vertex.name)' already has edges"
            }
            return
        }

        $qualifiedTypeName = $vertex.entity.typedata.entitytypename
        $unqualifiedTypeName = $qualifiedTypeName.substring($graph.namespace.length + 1, $qualifiedTypename.length - $graph.namespace.length - 1)

        __AddEdgesToEntityTypeVertex $graph $vertex

        if ( $vertex.entity.type -ne 'Singleton' ) {
            __AddMethodTransitionsToVertex $graph $vertex
        } else {
            __CopyEntityTypeEdgesToSingletonVertex $graph $vertex
        }
    }

    function __AddEdgesToEntityTypeVertices($graph, $typeName) {
        # This is the unqualifiedtypename -- seems inefficient
        # Why not just look up the type by key (i.e. qualified type name)
        $typeVertices = if ( $typeName ) {
            $graph.typeVertices.values | where name -eq $typeName
        } else {
            $graph.typeVertices.Values
        }

        $typeVertices | foreach {
            __AddEdgesToEntityTypeVertex $graph $_
        }
    }

    function __CopyEntityTypeEdgesToSingletons($graph, $singletonName) {
        # Only needed for precomputed case?
        __CopyEntityTypeEdgesToSingletonsByName $graph $singletonName
    }

    function __CopyEntityTypeEdgesToSingletonsByName($graph, $singletonName) {
        # only needed for precomputed case?
        $rootVertices = ($graph |=> GetRootVertices).values
        $singletonCandidates = if ( $singletonName ) {
            $rootVertices | where Name -eq $singletonName
        } else {
            $rootVertices
        }

        $singletonCandidates | foreach {
            if ( $_.type -eq 'Singleton' ) {
                __CopyEntityTypeEdgesToSingletonVertex $graph $_
            }
        }
    }

    function __CopyEntityTypeEdgesToSingletonVertex($graph, $source) {
        if ( $source.TestFlags([BuildFlags]::CopiedToSingleton) ) {
            throw "Data from type already copied to singleton '$($source.name)'"
        }

        $entityName = ($source.entity.typeData).EntityTypeName
        $typeVertex = $graph |=> TypeVertexFromTypeName $entityName

        if ( $typeVertex -eq $null ) {
            throw "Unable to find an entity type for singleton '$($_.name)' and '$entityName'"
        }

        __AddEdgesToVertex $graph $typeVertex $true

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

    function __UpdateProgress($deltaPercent) {
        $metadataActivity = "Building graph version '$($this.version)' for endpoint '$($this.graphEndpoint)'"

        $this.percentComplete += $deltaPercent
        $completionArguments = if ( $this.percentComplete -ge 100 ) {
            @{Status="Complete";PercentComplete=100;Completed=[System.Management.Automation.SwitchParameter]::new($true)}
        } else {
            @{Status="In progress";PercentComplete=$this.percentComplete}
        }
        $::.ProgressWriter |=> WriteProgress -id 1 -activity $metadataActivity @completionArguments
    }

    function __AddMethodTransitionsToVertex($graph, $sourceVertex) {
        if ( $sourceVertex.TestFlags([BuildFlags]::MethodsProcessed) ) {
            write-verbose "Methods already processed for $($sourceVertex.name), skipping method addition"
            return
        }

        $sourceTypeName = $sourceVertex.entity.typeData.EntityTypeName
        $methods = $graph.methodBindings[$sourceTypeName]

        if ( ! $methods ) {
            write-verbose "Vertex ($sourceVertex.name) has no methods, skipping method addition"
            return
        }

        $methods | foreach {
            $method = $_
            $sink = if ( $method | gm ReturnType ) {
                $typeName = if ( $method.localname -eq 'function' ) {
                    $method.ReturnType | select -expandproperty Type
                } else {
                    $method.ReturnType | select -expandproperty Type
                }

                $typeVertex = $graph |=> TypeVertexFromTypeName $typeName

                if ( $typeVertex -eq $null ) {
                    $name = $typeName
                    $unqualifiedName = if ( $name.startswith($graph.namespace) ) {
                        $name.substring($graph.namespace.length + 1, $name.length - $graph.namespace.length - 1)
                    }
                    if ( $unqualifiedName ) {
                        try {
                            __AddEntityTypeVertex $graph $unqaulifiedName
                         #   __AddEntityTypeVertices $graph $unqualifiedName
                            $typeVertex = $graph |=> TypeVertexFromTypeName $typeName
                        } catch {
                            # Possibly an enumeration type, this will just be considered a scalar
                        }
                    } else {
                        write-verbose "Unable to find schema for method '$($method.name)' with type '$typeName'"
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

    function __AddMethodTransitionsByType($graph, $targetTypeName) {
        $typeNames = if ( $targetTypeName ) {
            $targetTypeName
        } else {
            $graph.methodBindings.keys
        }

        $typeNames | foreach {
            $typeVertex = $graph |=> TypeVertexFromTypeName $_
            __AddMethodTransitionsToVertex $graph $typeVertex
        }
    }

    function __AddMethod($targetVertex, $methodSchema, $returnTypeVertex) {
        if ( ! ($targetVertex |=> EdgeExists($methodSchema.name)) ) {
            $methodEntity = new-so Entity $methodSchema $this.namespace
            $edge = new-so EntityEdge $targetVertex $returnTypeVertex $methodEntity
            $targetVertex |=> AddEdge $edge
        } else {
            write-verbose "Skipped add of edge $($methodSchema.name) to $($returnTypeVertex.id) from vertex $($targetVertex.id) because it already exists."
        }
    }
}

