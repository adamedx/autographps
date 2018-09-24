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

ScriptClass GraphBuilder {

    $graphEndpoint = $null
    $version = $null
    $dataModel = $null
    $namespace = $null
    $percentComplete = 0
    $metadata = $null
    $deferredBuild = $false

    function __initialize($graphEndpoint, $version, $metadata, $deferredBuild) {
        $this.graphEndpoint = $graphEndpoint
        $this.version = $version
        $this.metadata = $metadata
        $this.dataModel = new-so GraphDataModel $metadata
        $this.namespace = $this.dataModel |=> GetNamespace
        $this.deferredBuild = $deferredBuild
    }

    function NewGraph {
        $graph = new-so EntityGraph $this.namespace $this.version $this.graphEndpoint

        __UpdateProgress 0

        __AddRootVertices $graph

#        __AddEntitytypeVertices $graph

#        __AddEdgesToEntityTypeVertices $graph

#        __ConnectEntityTypesWithMethodEdges $graph

#        __CopyEntityTypeEdgesToSingletons $graph

        __UpdateProgress 100

        $graph
    }

    function AddEntityTypeVertex($graph, $typeName) {
        __AddEntityTypeVertex $graph $typeName
    }

    function __AddRootVertices($graph) {
        $singletons = $this.dataModel |=> GetSingletons
        __AddVerticesFromSchemas $graph $singletons

        $entitySets = $this.dataModel |=> GetEntitySets
        __AddVerticesFromSchemas $graph $entitySets

        __UpdateProgress 5
    }

    function __AddVerticesFromSchemas($graph, $schemas, $singleType = $false) {
        $progressIndex = 0

        if ( $singleType ) {
            __AddVertex $graph $schemas
        } else {
            $schemas | foreach {
                __AddVertex $graph $_
                $progressIndex += 1
            }
        }
    }

    function __AddVertex($graph, $schema) {
        $entity = new-so Entity $schema $this.namespace
        $graph |=> AddVertex $entity
    }

    function __AddEntityTypeVertices($graph, $typeName) {
        $entityTypes = $this.dataModel |=> GetEntityTypes $typeName
#        $this.dataModel.SchemaData.Edmx.DataServices.Schema.EntityType | select -first 5 | out-host
#        write-host 'addentitytypevertices', $typeName
#        write-host "types", $entityTypes.gettype()
#        if ( $graph.typeVertices[$typeName] ) {
#            throw 'anger'
#        }

        $singleType = $typeName -ne $null
        if ( $singleType -and $entityTypes -eq $null ) {
            throw "Type '$typeName' does not exist in the schema for the graph at endpoint '$($graph.endpoint)' with API version '$($graph.apiversion)'"
        }

        __AddVerticesFromSchemas $graph $entityTypes $singleType

        __UpdateProgress 20
    }

    function __AddEdgesToEntityTypeVertices($graph, $typeName) {
        $types = if ( $typeName ) {
            write-host 'addentitytypevertices got called for single type', $typeName
            $graph.typeVertices.values | where name -eq $typeName
        } else {
            $graph.typeVertices.Values
        }

        $progressIndex = 0

        $types | foreach {
            write-host "entitytype", $_.name
            $source = $_
            $transitions = if ( $source.entity.navigations ) {
                $source.entity.navigations
            } else {
                @()
            }
            $transitions | foreach {
                $transition = $_
                $sink = $graph |=> TypeVertexFromTypeName $transition.typedata.entitytypename

                if ( $typeName -and ($sink -eq $null) ) {
                    $name = $transition.typedata.entitytypename
                    write-host 'trying to get', $name
                    $unqualifiedName = $name.substring($graph.namespace.length + 1, $name.length - $graph.namespace.length - 1)
                    $sinkSchema = $this.datamodel |=> GetEntityTypes $unqualifiedName
                    if ( $sinkSchema ) {
                        __AddEntityTypeVertices $graph $unqualifiedName
                        $sink = $graph |=> TypeVertexFromTypeName $transition.typedata.entitytypename
                    } else {
                        write-verbose "Unable to find schema for '$($transition.type)', $($transition.typedata.entitytypename)"
                    }
                }
                if ( $sink -ne $null ) {
                    $edge = new-so EntityEdge $source $sink $transition
                    $source |=> AddEdge $edge
                } else {
                    write-verbose "Unable to find entity type for '$($transition.type)', $($transition.typedata.entitytypename), skipping"
                }
            }
            $source.buildState.NavigationsAdded = $true
            $progressIndex += 1
        }
        __UpdateProgress 40
    }

    function __ConnectEntityTypesWithMethodEdges($graph, $typeName) {
        $actions = $this.dataModel |=> GetActions
        __AddMethodTransitions $graph $actions $typeName

        $functions = $this.dataModel |=> GetFunctions
        __AddMethodTransitions $graph $functions $typeName

        __UpdateProgress 75
    }

    function __CopyEntityTypeEdgesToSingletons($graph, $singletonName) {
        if ( ! $this.deferredBuild ) {
            $this.scriptclass |=> __CopyEntityTypeEdgesToSingletons $graph $singletonName
        } else {
            write-verbose "Deferred build set -- skipping connection of singletons to entity types to avoid deserialization depth issues"
        }
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

    function __AddMethodTransitions($graph, $methods, $targetTypeName) {
        $methods | foreach {
            $parameters = try {
                $_.parameter
            } catch {
            }

            $method = $_
            $source = if ( $parameters ) {
                $bindingParameter = $parameters | where { $_.name -eq 'bindingParameter' -or $_.name -eq 'bindParameter' }
                if ( $bindingParameter ) {
                    if ( ( $targetTypeName -eq $null ) -or ($bindingParameter.Type -eq $targetTypeName) ) {
                        if ( $targetTypeName ) {
                            write-host -fore cyan "Found '$targetTypeName'!"
                        }
                        $bindingTargetVertex = $graph |=> TypeVertexFromTypeName $bindingParameter.Type

                        if ( $bindingTargetVertex ) {
                            $bindingTargetVertex
                        } else {
                            write-verbose "Unable to bind method '$($_.name)' of type '$($bindingParameter.Type)', skipping"
                        }
                    } else {
                        write-host -fore magenta "Skipping '$($bindingParameter.Type)', not eq '$targetTypeName'"
                        write-verbose "Skipping '$($bindingParameter.Type)', not eq '$targetTypeName'"
                    }
                } else {
                    write-host -fore cyan "Unable to find a bindingParameter in parameters for $($_.name)"
                }
            } else {
                write-verbose "Method '$($_.name)' does not have a parameter attribute, skipping"
            }

            if ( $source ) {
                $sink = if ( $method | gm ReturnType ) {
                    $typeName = if ( $method.localname -eq 'function' ) {
                        $method.ReturnType | select -expandproperty Type
                    } else {
                        $method.ReturnType | select -expandproperty Type
                    }

                    $typeVertex = $graph |=> TypeVertexFromTypeName $typeName

                    if ( $typeVertex -eq $null ) {
#                        $name = ($::.Entity |=> GetEntityTypeDataFromTypeName $typeName).entitytypename | select -expandproperty type
                        $name = $typeName
                        write-host "Method '$($method.name)' has return type '$name', looking for it"
                        $unqualifiedName = if ( $name.startswith($graph.namespace) ) {
                            $name.substring($graph.namespace.length + 1, $name.length - $graph.namespace.length - 1)
                        }
                        if ( $unqualifiedName ) {
                            try {
                                __AddEntityTypeVertices $graph $unqualifiedName
                                $typeVertex = $graph |=> TypeVertexFromTypeName $typeName
                            } catch {
                                # Possibly an enumeratio type, this will just be considered a scalar
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

                __AddMethod $source $method $sink
            }
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

    static {
        function CompleteDeferredBuild($graph) {
            write-verbose "Completing deferred build by connecting singletons"
            __CopyEntityTypeEdgesToSingletons $graph
        }

        function __CopyEntityTypeEdgesToSingletons($graph, $singletonName) {
            $rootVertices = ($graph |=> GetRootVertices).values
            $singletonCandidates = if ( $singletonName ) {
                write-host 'targeted'
                $rootVertices | where Name -eq $singletonName
            } else {
                write-host 'everything'
                $rootVertices
            }

            $singletonCandidates | foreach {
                $source = $_
                $edges = if ( $source.type -eq 'Singleton' ) {
                    $entityName = ($source.entity.typeData).EntityTypeName
                    $typeVertex = $graph |=> TypeVertexFromTypeName $entityName
                    if ( $typeVertex -eq $null ) {
                        throw "Unable to find an entity type for singleton '$($_.name)' and '$entityName'"
                    }
                    $typeVertex.outgoingEdges.values | foreach {
                        if ( ( $_ | gm transition ) -ne $null ) {
                            $_
                        }
                    }
                }

                $edges | foreach {
                    $sink = $_.sink
                    $transition = $_.transition
                    $edge = new-so EntityEdge $source $sink $transition
                    $source |=> AddEdge $edge
                }
            }
        }
    }
}

