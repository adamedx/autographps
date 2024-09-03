# Copyright 2024, Adam Edwards
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

. (import-script ../common/PreferenceHelper)
. (import-script GraphDataModel)
. (import-script EntityGraph)

enum MetadataStatus {
    NotStarted
    Pending
    Ready
    Failed
    Unknown
}

ScriptClass GraphCache -ArgumentList { __Preference__ShowNotReadyMetadataWarning } {
    param($metadataWarningBlock)
    $graphVersionsPending = @{}
    $graphVersions = @{}

    function __initialize {
        $this.graphVersionsPending = @{}
        $this.graphVersions = @{}
    }

    function GetGraph($endpointUri, $apiVersion = 'v1.0', $metadata = $null, $schemaId, $schemaUri) {
        $graph = FindGraph $endpointUri $apiVersion $schemaId

        if ( $graph ) {
            $graph
        } else {
            $graphJob = GetGraphAsync $endpointUri $apiVersion $metadata $schemaId $schemaUri
            WaitForGraphAsync $graphJob
        }
    }

    function FindGraph($endpoint, $apiVersion, $schemaId) {
        $graphId = $this.scriptclass |=> __GetGraphId $endpoint $apiVersion $schemaId
        $this.graphVersions[$graphId]
    }

    function GetGraphAsync($endpoint, $apiVersion = 'v1.0', $metadata = $null, $schemaId, $schemaUri) {
        $graphId = $this.scriptclass |=> __GetGraphId $endpoint $apiVersion $schemaId
        $existingJob = $this.graphVersionsPending[$graphId]
        if ( $existingJob ) {
            write-verbose "Found existing job '$($existingJob.job.id)' for '$graphId'"
            $existingJob
        } else {
            write-verbose "No existing job for '$graphId' -- queueing up a new job"
            __GetGraphAsync $graphId $endpoint $apiVersion $metadata $schemaId $schemaUri
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
                . $metadataWarningBlock
            }

            $elapsedMs = 0
            $waitIntervalMs = 10000
            $resultJob = $null
            # Use a busy wait of sorts to avoid deadlocks
            while ( $elapsedMs -lt (60 * $waitIntervalMs) -and ! (
                        $resultJob = $submittedVersion.job | wait-job -timeout $waitIntervalMs -erroraction stop ) ) {
                $elapsedMs += $waitIntervalMs
            }

            if ( ! $resultJob ) {
                throw "Metadata processing job failed to complete after $elapsedMs milliseconds";
            }

            write-verbose "Receiving job"
            $resultJob | receive-job -erroraction stop
            write-verbose "Received job"
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

    function GetMetadataStatus($endpoint, $apiVersion, $schemaId) {
        $graphid = $this.scriptclass |=> __GetGraphId $endpoint $apiversion $schemaId
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

    function __GetGraphAsync($graphId, $endpoint, $apiVersion, $metadata, $schemaId, $schemaUri) {
        write-verbose "Getting async graph for graphid: '$graphId', endpoint: '$endpoint', version: '$apiVersion' at URI '$schemaUri'"
        write-verbose "Local metadata supplied: '$($metadata -ne $null)' with id '$schemaId'"

        $cacheClass = $::.GraphCache

        # Start-ThreadJob starts a ThreadJob, a job running in another thread in this process rather than a separate process. It is much more efficient,
        # but very strange things occur if ScriptClass method functionality is invoked, possibly because of the way ScriptClass interacts with the call
        # stack. Due to this, the safest way to pass in ScriptClass state is to pass in an object, and use standard method call syntax rather than
        # ScriptClass syntax to invoke it. Regardless, Start-ThreadJob is far more efficient than Start-Job AND it doesn't have to serialize and
        # deserialize objects -- many of the strange workarounds in this module to ensure that ScriptClass object state was preserved is no longer
        # a necessity, though most of those workarounds are now built in to ScriptClass itself. It may even be feasible to parse the entire graph
        # rather than only parse just in time since the entire graph can be parsed efficiently in the background without being serialized and deserialized.
        $graphLoadJob = Start-ThreadJob { param($cacheClass, $graphEndpoint, $version, $schemadata, $schemaId, $schemaUri, $verbosity) $verbosepreference=$verbosity; $__poshgraph_no_auto_metadata = $true; $cacheClass.__GetGraph($graphEndpoint, $version, $schemadata, $schemaId, $schemaUri) } -argumentlist $cacheClass, $endpoint, $apiVersion, $metadata, $schemaId, $schemaUri, $verbosepreference  -name "AutoGraphPS metadata download for '$graphId'"

        $graphAsyncJob = [PSCustomObject]@{Job=$graphLoadJob;Id=$graphId}
        write-verbose "Saving job '$($graphLoadJob.Id) for graphid '$graphId'"
        $this.graphVersionsPending[$graphId] = $graphAsyncJob
        $graphAsyncJob
    }

    static {
        function __GetGraph($endpoint, $apiVersion, $metadata, $schemaId, $schemaUri) {
            $graphId = __GetGraphId $endpoint $apiVersion $schemaId
            $schemadata = if ( $metadata ) {
                write-verbose "Using locally supplied metadata, skipping retrieval from remote Graph"
                $metadata
            } else {
                __GetSchema $endpoint $apiVersion $schemaUri
            }
            [PSCustomObject]@{Id=$graphId;SchemaData=$schemadata;Endpoint=$endpoint;Version=$apiVersion}
        }

        function __GetGraphId($endpoint, $apiVersion, $schemaId) {
            if ( $schemaId ) {
                "id=$($schemaId)"
            } else {
                "{0}:{1}" -f $endpoint, $apiVersion
            }
        }

        function __GetSchema([Uri] $endpointUri, $apiVersion, $schemaUri) {
            if ( ! $schemaUri ) {
                throw 'An empty schema URI was specified'
            }

            $fromLocal = switch ( ( [Uri] $schemaUri ).scheme ) {
                'file' { $true }
                'https' { $false }
                default {
                    throw "The specified URI '$schemaUri' did not conform to a valid file or https scheme"
                }
            }

            $metadataActivity = "Reading metadata for graph version '$apiversion' for endpoint '$endpoint' from URI $schemaUri"
            Write-Progress -id 1 -activity $metadataactivity -status "Downloading"

            $graphEndpoint = new-so GraphEndpoint Custom $endpointUri http://localhost 'Default'
            $connection = new-so GraphConnection $graphEndpoint $null $null

            $schema = try {
                write-verbose 'Sending request'

                $schemaContent = if ( $fromLocal ) {
                    write-debug "Reading from local file '$schemaUri'"
                    Get-Content $schemaUri
                } else {
                    write-debug "Reading from remote URI '$schemaUri'"
                    Invoke-GraphApiRequest -connection $connection '$metadata' -version $apiversion -erroraction stop -rawcontent
                }

                write-debug "Finished reading schema content"
                write-debug "Parsing schema content as XML"

                [xml] ( $schemaContent | out-string )

                write-debug "Completed parsing of schema content as XML"
                write-verbose 'Request completed'
            } catch {
                write-verbose "Invoke-GraphApiRequest failed to download schema"
                write-verbose $_
                write-verbose $_.exception
                throw
            }

            Write-Progress -id 1 -activity $metadataactivity -status "Download complete" -completed

            $schema
        }
    }
}

