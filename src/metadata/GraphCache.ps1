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

. (import-script ..\common\PreferenceHelper)
. (import-script GraphDataModel)
. (import-script EntityGraph)

enum MetadataStatus {
    NotStarted
    Pending
    Ready
    Failed
    Unknown
}

ScriptClass GraphCache {
    $graphVersionsPending = @{}
    $graphVersions = @{}

    function __initialize {
        $this.graphVersionsPending = @{}
        $this.graphVersions = @{}
    }

    function GetGraph($endpoint, $apiVersion = 'v1.0', $metadata = $null) {
        $graph = FindGraph $endpoint $apiVersion

        if ( $graph ) {
            $graph
        } else {
            $graphJob = GetGraphAsync $endpoint $apiVersion $metadata
            WaitForGraphAsync $graphJob
        }
    }

    function FindGraph($endpoint, $apiVersion) {
        $graphId = $this.scriptclass |=> __GetGraphId $endpoint $apiVersion
        $this.graphVersions[$graphId]
    }

    function GetGraphAsync($endpoint, $apiVersion = 'v1.0', $metadata = $null) {
        $graphid = $this.scriptclass |=> __GetGraphId $endpoint $apiVersion
        $existingJob = $this.graphVersionsPending[$graphId]
        if ( $existingJob ) {
            write-verbose "Found existing job '$($existingJob.job.id)' for '$graphId'"
            $existingJob
        } else {
            write-verbose "No existing job for '$graphId' -- queueing up a new job"
            __GetGraphAsync $graphId $endpoint $apiVersion $metadata
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
            if ( (get-job $submittedVersion.job.id).State -eq 'Running' ) {
                __Preference__ShowNotReadyMetadataWarning
            }
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
                $this.graphVersionsPending.Remove($graphId)
                remove-job $submittedVersion.job -force
                $schemaData = [xml] $jobResult.schemaData
                $graph = $::.EntityGraph |=> NewGraph $jobResult.endpoint $jobresult.version $schemadata
                $this.graphVersions[$graphId] = $Graph
            } else {
                write-verbose "Completed job '$($submittedVersion.job.id)' for graph '$graphid', but no pending version found, so this is a no-op"
            }
        } else {
            # The call may have been completed by someone else --
            # this is common since we always wait on the async
            # result, so if more than one caller asks for a graph,
            # all but the first will hit this path
            write-verbose "Job '$($submittedVersion.job.id)' for graph '$graphId' completed with no result -- another caller may have already completed the call"

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

    function CancelPendingGraph($endpoint, $apiVersion) {
        $graphid = $this.scriptclass |=> __GetGraphId $endpoint $apiversion
        $pendingGraph = $this.graphVersionsPending[$graphid]
        if ( $pendingGraph ) {
            $pendingGraph.job | stop-job
            $this.graphVersionsPending.Remove($graphId)
        }
    }

    function GetMetadataStatus($endpoint, $apiVersion) {
        $graphid = $this.scriptclass |=> __GetGraphId $endpoint $apiversion
        $status = [MetadataStatus]::NotStarted

        if ($this.Graphversions[$graphId] -ne $null) {
            $status = [MetadataStatus]::Ready
        } else {
            $pendingVersion = $this.graphVersionsPending[$graphid]

            if ( $pendingVersion ) {
                $status = switch ( $pendingVersion.job.state ) {
                    'Completed' { ([MetadataStatus]::Ready) }
                    'Running' { ([MetadataStatus]::Pending) }
                    'Failed' { ([MetadataStatus]::Failed) }
                    default { ([MetadataStatus]::Unknown) }
                }
            }
        }

        $status
    }

    function __GetGraphAsync($graphId, $endpoint, $apiVersion, $metadata) {
        write-verbose "Getting async graph for graphid: '$graphId', endpoint: '$endpoint', version: '$apiVersion'"
        write-verbose "Local metadata supplied: '$($metadata -ne $null)'"

        $dependencyModule = join-path $psscriptroot '..\..\autographps.psd1'
        $thiscode = join-path $psscriptroot '..\graph.ps1'

        $graphLoadJob = start-job { param($module, $scriptsourcepath, $graphEndpoint, $version, $schemadata, $verbosity) $verbosepreference=$verbosity; $__poshgraph_no_auto_metadata = $true; import-module $module; . $scriptsourcepath; $::.GraphCache |=> __GetGraph $graphEndpoint $version $schemadata } -argumentlist $dependencymodule, $thiscode, $endpoint, $apiVersion, $metadata, $verbosepreference  -name "AutoGraphPS metadata download for '$graphId'"

        $graphAsyncJob = [PSCustomObject]@{Job=$graphLoadJob;Id=$graphId}
        write-verbose "Saving job '$($graphLoadJob.Id) for graphid '$graphId'"
        $this.graphVersionsPending[$graphId] = $graphAsyncJob
        $graphAsyncJob
    }

    static {
        function __GetGraph($endpoint, $apiVersion, $metadata) {
            $graphId = __GetGraphId $endpoint $apiVersion
            $schemadata = if ( $metadata ) {
                write-verbose "Using locally supplied metadata, skipping retrieval from remote Graph"
                $metadata
            } else {
                __GetSchema $endpoint $apiVersion
            }
            [PSCustomObject]@{Id=$graphId;SchemaData=$schemadata;Endpoint=$endpoint;Version=$apiVersion}
        }

        function __GetGraphId($endpoint, $apiVersion) {
            "{0}:{1}" -f $endpoint, $apiVersion
        }

        function __GetSchema($endpoint, $apiVersion) {
            $metadataActivity = "Reading metadata for graph version '$apiversion' from endpoint '$endpoint'"
            write-progress -id 1 -activity $metadataactivity -status "In progress"

            $graphEndpoint = new-so GraphEndpoint ([GraphCloud]::Public) ([GraphType]::MSGraph) $endpoint http://localhost ([GraphAuthProtocol]::Default)
            $connection = new-so GraphConnection $graphEndpoint $null $null
            $schema = try {
                invoke-graphrequest -connection $connection '$metadata' -version $apiversion -erroraction silentlycontinue -rawcontent
            } catch {
            }

            write-progress -id 1 -activity $metadataactivity -status "Complete" -completed
            $schema
        }
    }
}


