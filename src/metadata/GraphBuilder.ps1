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
. (import-script GraphContext)
. (import-script EntityEdge)
. (import-script EntityVertex)
. (import-script EntityGraph)

ScriptClass GraphBuilder {

    $graphContext = $null
    $dataModel = $null
    $namespace = $null
    $percentComplete = 0
    $metadata = $null

    function __initialize($graphContext, $metadata = $null) {
        $this.graphContext = $graphContext
        $this.metadata = $metadata
    }

    function NewGraph {
        if ( ! $this.dataModel ) {
            $metadata = if ($this.metadata)  {
                write-verbose "NewGraph: Using existing metadata instead of downloading"
                $this.metadata
            } else {
                $this.GraphContext |=> GetMetadata
            }
            $this.dataModel = new-so GraphDataModel $metadata
            $this.namespace = $this.dataModel |=> GetNamespace
        }

        __BuildGraph
    }

    function __BuildGraph {
        $endpoint = if ( $this.graphContext.connection ) {
            $this.graphContext.connection.graphendpoint.Graph
        } else {
            $null
        }

        $graph = new-so EntityGraph $this.namespace $this.graphContext.version $endpoint

        __UpdateProgress 0

        __AddRootVertices $graph

        __AddEntitytypeVertices $graph

        __AddEdgesToEntityTypeVertices $graph

        __ConnectEntityTypesWithMethodEdges $graph

        __CopyEntityTypeEdgesToSingletons $graph

        __UpdateProgress 100

        $graph
    }

    function __AddRootVertices($graph) {
        $singletons = $this.dataModel |=> GetSingletons
        __AddVerticesFromSchemas $graph $singletons

        $entitySets = $this.dataModel |=> GetEntitySets
        __AddVerticesFromSchemas $graph $entitySets

        __UpdateProgress 5
    }

    function __AddVerticesFromSchemas($graph, $schemas) {
        $progressTotal = $schemas.count
        $progressIndex = 0

        $schemas | foreach {
            $::.ProgressWriter |=> WriteProgress -id 2 -activity "Adding $($_.localname) vertices" -Status "In progress" -PercentComplete (100 * ($progressIndex / $progressTotal)) -currentoperation "Adding $($_.name)"
            __AddVertex $graph $_
            $progressIndex += 1
        }
    }

    function __AddVertex($graph, $schema) {
        $entity = new-so Entity $schema $this.namespace
        $graph |=> AddVertex $entity
    }

    function __AddEntityTypeVertices($graph) {
        $entityTypes = $this.dataModel |=> GetEntityTypes
        __AddVerticesFromSchemas $graph $entityTypes

        __UpdateProgress 20
    }

    function __AddEdgesToEntityTypeVertices($graph) {
        $types = $graph.typeVertices.Values
        $progressTotal = $types.count
        $progressIndex = 0

        $types | foreach {
            $source = $_
            $::.ProgressWriter |=> WriteProgress -id 2 -activity "Adding entity type navigations" -currentoperation "Processing entity $($source.name)" -percentcomplete (100 * ( $progressIndex / $progressTotal ))
            $transitions = if ( $source.entity.navigations ) {
                $source.entity.navigations
            } else {
                @()
            }
            $transitions | foreach {
                $transition = $_
                $sink = $graph |=> TypeVertexFromTypeName $transition.typedata.entitytypename
                if ( $sink -ne $null ) {
                    $edge = new-so EntityEdge $source $sink $transition
                    $source |=> AddEdge $edge
                } else {
                    write-verbose "Unable to find entity type for '$($transition.type)', skipping"
                }
            }
            $progressIndex += 1
        }
        __UpdateProgress 40
    }

    function __ConnectEntityTypesWithMethodEdges($graph) {
        $actions = $this.dataModel |=> GetActions
        __AddMethodTransitions $graph $actions

        $functions = $this.dataModel |=> GetFunctions
        __AddMethodTransitions $graph $functions

        __UpdateProgress 75
    }

    function __CopyEntityTypeEdgesToSingletons($graph) {
        ($graph |=> GetRootVertices).values | foreach {
            $source = $_
            $edges = if ( $source.type -eq 'Singleton' ) {
                $typeVertex = $graph |=> TypeVertexFromTypeName ($source.entity.typeData).EntityTypeName
                if ( $typeVertex -eq $null ) {
                    throw "Unable to find an entity type for type '$($source.entity.type)"
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
        __UpdateProgress 100
    }

    function __UpdateProgress($deltaPercent) {
        $endpoint = $this.GraphContext |=> GetGraphEndpoint
        $metadataActivity = "Building graph version '$($this.graphContext.version)' for endpoint '$endpoint'"

        $this.percentComplete += $deltaPercent
        $completionArguments = if ( $this.percentComplete -ge 100 ) {
            @{Status="Complete";PercentComplete=100;Completed=[System.Management.Automation.SwitchParameter]::new($true)}
        } else {
            @{Status="In progress";PercentComplete=$this.percentComplete}
        }
        $::.ProgressWriter |=> WriteProgress -id 1 -activity $metadataActivity @completionArguments
    }

    function __AddMethodTransitions($graph, $methods) {
        $methods | foreach {
            $parameters = try {
                $_.parameter
            } catch {
            }

            $method = $_
            $source = if ( $parameters ) {
                $bindingParameter = $parameters | where { $_.name -eq 'bindingParameter' }
                if ( $bindingParameter ) {
                    $bindingTargetVertex = $graph |=> TypeVertexFromTypeName $bindingParameter.Type

                    if ( $bindingTargetVertex ) {
                        $bindingTargetVertex
                    } else {
                        write-verbose "Unable to bind '$($_.name)' of type '$($bindingParameter.Type)', skipping"
                    }
                } else {
                    write-verbose "Unable to find a bindingParameter in parameters for $($_.name)"
                }
            } else {
                write-verbose "Method '$($_.name)' does not have a parameter attribute, skipping"
            }

            if ( $source ) {
                $sink = if ( $method | gm ReturnType ) {
                    $typeName = if ( $method.localname -eq 'function' ) {
                        $method.ReturnType.Type
                    } else {
                        $method.ReturnType
                    }

                    $typeVertex = $graph |=> TypeVertexFromTypeName $typeName

                    if ( $typeVertex ) {
                        $typeVertex
                    } else {
                        write-verbose "Type $($typeName) returned by $($method.name) cannot be found, configuring null vertex"
                        $::.EntityVertex.NullVertex
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
        $graphVersionsPending = @{}
        $graphVersions = @{}

        function GetGraph($apiVersion = 'v1.0', $connection, $metadata = $null) {
            $context = __GetContext $apiVersion $connection
            $graph = $this.graphVersions[$context.id]
            if ( $graph ) {
                $graph
            } else {
                $graphJob = GetGraphAsync $apiVersion $context.Connection $metadata
                WaitForGraphAsync $graphJob
            }
        }

        function GetGraphAsync($apiVersion = 'v1.0', $connection, $metadata = $null) {
            $context = __GetContext $apiVersion $connection
            $graphid = $context.id
            $existingJob = $this.graphVersionsPending[$graphId]
            if ( $existingJob ) {
                write-verbose "Found existing job '$($existingJob.job.id)' for '$graphId'"
                $existingJob
            } else {
                write-verbose "No existing job for '$graphId' -- queueing up a new job"
                 __GetGraphAsync $graphId $apiVersion $context.connection $metadata
            }
        }

        function WaitForGraphAsync($graphAsyncResult) {
            $graphId = $graphAsyncResult.Id
            $submittedVersion = $this.graphVersionsPending[$graphId]

            $jobNotFound = if ( ! $submittedVersion ) {
                write-verbose "No existing job found for '$graphId'"
                $true
            } elseif ($submittedVersion.job.id -ne $graphAsyncResult.job.id ) {
                write-verbose "Found job for '$graphId', but queued job '$($submittedVersion.job.id)' does not match requested job '$($graphAsyncResult.job.id)'"
            }

            if ( $jobNotFound ) {
                write-verbose "No existing job found for '$graphId', checking for it in completed versions"
                $existingVersion = $this.GraphVersions[$graphId]
                if ( $existingVersion[$graphId] ) {
                    write-verbose "Found completed version for '$graphId', returning it"
                    return $existingVersion
                }
                throw "No queued version found for '$graphId'"
            }

            write-verbose "Found unfinished job '$($submittedVersion.job.id)' for graph '$graphId' -- waiting for it"

            # This is only retrieved by the first caller for this job --
            # subsequent jobs return $null
            $jobException = $null
            $jobResult = try {
                receive-job -wait $submittedVersion.Job -erroraction stop
            } catch {
                $jobException = $_.exception
            }

            if ( $jobResult ) {
                # Only one caller will set this for a given job since
                # receive-job only returns a non-null result for the
                # first caller
                write-verbose "Successfully retrieved job result for $($submittedVersion.job.id) for graph '$graphId'"
                if ( $this.graphVersionsPending[$graphId] ) {
                    write-verbose "Removing pending version for job '$($submittedVersion.job.id)' for graph '$graphId'"
                    $this.graphVersions[$graphId] = $jobResult.Graph
                    $this.graphVersionsPending.Remove($graphId)
                    remove-job $submittedVersion.job -force
                } else {
                    write-verbose "Completed job '$($submittedVersion.job.id)' for graph '$graphid', but no pending version found, so this is a no-op"
                }
            } else {
                # The call may have been completed by someone else --
                # this is common since we always wait on the async
                # result, so if more than one caller asks for a graph,
                # all but the first will hit this path
                write-verbose "Job '$($submittedVersion.job.id)' for graph '$graphId' completed wtih no result -- another caller may have already completed the call"

                # If it was completed, it should be listed in graphversions
                if ( $this.graphVersionsPending[$graphId] ) {
                    write-verbose "Removing pending version for job '$submittedVersion.job.id' for graph '$graphId'"
                    $this.graphVersionsPending.Remove($graphId)
                    remove-job $submittedVersion.job -force
                }

                $completedGraph = $this.graphVersions[$graphId]
                if ( ! $completedGraph ) {
                    if ( $jobException ) {
                        throw $jobException
                    }

                    throw "No pending or successful job '$($submittedVersion.job.id)' for building graph with id '$graphId'"
                }
            }

            write-verbose "Successfully returning graph '$graphid' from job '$($submittedversion.job.id)'"
            $this.graphVersions[$graphId]
        }

        function CancelPendingGraph($apiVersion, $connection) {
            $graphid = $::.GraphContext |=> GetContextId $connection $apiversion
            $pendingGraph = $this.graphVersionsPending[$graphid]
            if ( $pendingGraph ) {
                $pendingGraph.job | stop-job
                $this.graphVersionsPending.Remove($graphId)
            }
        }

        function __GetGraphAsync($graphId, $apiVersion, $connection, $metadata) {
            $dependencyModule = get-module 'poshgraph'
            $thiscode = join-path $psscriptroot '..\graph.ps1'
            $graphLoadJob = start-job { param($module, $scriptsourcepath, $version, $graphConnection, $schemadata) import-module $module; . $scriptsourcepath; $::.GraphBuilder |=> __GetGraph $version $graphConnection $schemadata } -argumentlist $dependencymodule, $thiscode, $apiVersion, $connection, $metadata -name "PoshGraph metadata download for '$graphId'"
            $graphAsyncJob = [PSCustomObject]@{Job=$graphLoadJob;Id=$graphId}
            write-verbose "Saving job '$($graphLoadJob.Id) for graphid '$graphId'"
            $this.graphVersionsPending[$graphId] = $graphAsyncJob
            $graphAsyncJob
        }

        function __GetGraph($apiVersion, $connection, $metadata) {
            $graphContext = new-so GraphContext $connection $apiVersion
            $graphId = $graphContext.id

            $builder = new-so GraphBuilder $graphContext $metadata
            $graph = $builder |=> NewGraph

            [PSCustomObject]@{Graph=$graph;Id=$graphId}
        }

        function __GetContext($apiVersion, $connection) {
            $graphConnection = if ( ! $connection ) {
                $::.GraphConnection |=> GetDefaultConnection ([GraphType]::MSGraph) -anonymous $true
            } else {
                $connection
            }

            new-so GraphContext $graphConnection $apiVersion
        }
    }
}

