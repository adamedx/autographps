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
        $timedOut = $false

        $jobResult = try {
            if ( (get-job $submittedVersion.job.id).State -eq 'Running' ) {
                . $metadataWarningBlock
            }

            $elapsedSeconds = 0
            $waitIntervalSeconds = 10
            $resultJob = $null
            # Use a busy wait of sorts to avoid deadlocks
            while ( $elapsedSeconds -lt (12 * $waitIntervalSeconds) ) {
                write-verbose "Will wait for job to complete for '$waitIntervalSeconds' seconds..."

                $resultJob = $submittedVersion.job |
                  Wait-Job -timeout $waitIntervalSeconds -erroraction stop

                if ( $resultJob ) {
                    write-verbose "Wait completed successfully"
                    break
                }

                $elapsedSeconds += $waitIntervalSeconds
                write-verbose "Wait timed out, total wait time is '$elapsedSeconds' seconds, will retry"
            }

            if ( $resultJob ) {
                $resultJob | receive-job -erroraction stop
            } else {
                $timedOut = $true
            }

            write-verbose "Metadata processing job completed after $elapsedSeconds seconds";
        } catch {
            $jobException = $_.exception
        }

        if ( ! $jobResult -and $timedOut ) {
            write-verbose "Metadata timeout detected -- removing from table pending version for job '$submittedVersion.job.id' for graph '$graphId'"

            $this.graphVersionsPending.Remove($graphId)

            write-warning "The job with job id=$($submittedVersion.job.id) to download and process Graph metadata is slow or deadlocked -- it is being abandoned and a new job will be started instead. Use Get-Job and related commands to manage this job."
        } elseif ( $jobResult ) {
            # Only one caller will set this for a given job since
            # receive-job only returns a non-null result for the
            # first caller
            write-verbose "Successfully retrieved job result for $($submittedVersion.job.id) for graph '$graphId'"
            if ( $this.graphVersionsPending[$graphId] ) {
                write-verbose "Removing pending version for job '$($submittedVersion.job.id)' for graph '$graphId'"

                $this.graphVersionsPending.Remove($graphId)
                remove-job $submittedVersion.job -force

                write-verbose "Successfully removed job"

                $schemaData = [xml] $jobResult.schemaData
                $graph = $::.EntityGraph |=> NewGraph $jobResult.endpoint $jobresult.version $schemadata
                $this.graphVersions[$graphId] = $Graph
            } else {
                write-verbose "Completed job '$($submittedVersion.job.id)' for graph '$graphid', but no pending version found, so this is a no-op"
            }
        } else {
            # The call may have been completed by a different caller for a different thread --
            # this is common since we always wait on the async
            # result, so if more than one caller asks for a graph,
            # all but the first will hit this path. This is not considered
            # a failure -- the metadata should be available in the cache
            # since the previous job completed; no new job is needed. We will
            # still check to see if it is actually in the cache.
            write-verbose "Job '$($submittedVersion.job.id)' for graph '$graphId' completed with no result -- another caller may have already completed the call"

            # Remove it from the pending versions since we couldn't get a result for it anyway. This will
            # also prevent us from repeating this same condition on future requests for this graph id if
            # they are retried by the user.
            if ( $this.graphVersionsPending[$graphId] ) {
                write-verbose "Removing pending version for not found job '$submittedVersion.job.id' for graph '$graphId'"

                $this.graphVersionsPending.Remove($graphId)
                remove-job $submittedVersion.job -force

                write-verbose "Finished removing not found job"
            }

            # If it was completed by another thread, it should be listed in graphversions -- if it isn't,
            # this is not expected and is an error condition.
            $completedGraph = $this.graphVersions[$graphId]
            if ( ! $completedGraph ) {
                if ( $jobException ) {
                    throw $jobException
                }

                throw "No pending or successful job '$($submittedVersion.job.id)' for building graph with id '$graphId' -- metadata download and processing failed for an unknown reason."
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

        # We're going to use Start-ThreadJob to create a new thread to download from. A better idea might be to just use a .NET async method
        # directly as opposed to wrapping this in a thread.

        # The idea is to invoke a method from this class on the other thread. However, ScriptClass classes are not visible outside of this thread.
        # To address this, we can simply pass in a ScriptClass class object itself into the thread. Static methods on that class will
        # function just fine because they are actually just object methods anyway -- they have to be invoked with normal method syntax rather than
        # scriptclass static method syntax though.

        # HOWEVER: There is a big limitation with ScriptClass due to the following ScriptClass issue: https://github.com/adamedx/scriptclass/issues/40 :
        #
        # * When New-ScriptObject (i.e. new-so) is invoked from the static method defined outside of the job for any types contained in a module
        #   other than the code that invoked Start-ThreadJob will not work -- New-ScriptObject will actually HANG. You'll need to use CTRL-C
        #   to get out of the hang, and in fact this exposes some latent bug in PowerShell Core itself because subsequently using the exit command
        #   to exit PowerShell itself hangs; clearly nothing we do should be able to break exit.
        # * This issue does not impact usage of New-ScriptObject from within commands exposed by the other module.
        # * But this does mean that any static methods from types passed in to the job's scriptblock must not use New-ScriptObject.
        # * A possible workaround was explored where we create any such objects outside of the job and pass them in as parameters, but it seems the
        #   behavior remained at least with the initial attempt; the hang in this case was not sufficiently pinpointed to see if we could tweak the workaround.

        # Get a class object we can pass in to the scriptblock so we can execute a static method. In this case, we are just
        # going to execute a static method from this class, so we get this class's class object.
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
                __GetSchema $schemaUri
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

        function __GetSchema([Uri] $schemaUri) {
            if ( ! $schemaUri ) {
                throw 'An empty schema URI was specified'
            }

            $schemaScheme = $schemaUri.scheme

            $fromLocal = switch ( $schemaScheme ) {
                'file' { $true }
                'https' { $false }
                default {
                    if ( $schemaScheme -ne $null ) {
                        throw "The specified URI '$schemaUri' did not conform to a valid file or https scheme"
                    }

                    # Assume this is a local file system path if the scheme is not set
                    $true
                }
            }

            $metadataActivity = "Reading metadata for graph from URI $schemaUri"
            Write-Progress -id 1 -activity $metadataactivity -status "Downloading"

            $schema = try {
                write-verbose "Sending request for schema id $schemaId"

                $schemaContent = if ( $fromLocal ) {
                    write-verbose "Reading from local file '$($schemaUri.OriginalString)'"

                    # Need to use OriginalString because it is the only field that
                    # is set consistently on all platforms for local file system paths
                    Get-Content $schemaUri.OriginalString
                } else {
                    write-verbose "Reading from remote URI '$schemaUri'"

                    # Ideally we'd use Invoke-GraphApiRequest, but because it is authenticated by default and does
                    # not currently support a parameter for anonymous access, we need to create some objects from ScriptClass
                    # to initialize a connection object. It turns out that even if we create this object outside of the ThreadJob
                    # in which this code will execute, we still hit the SCriptClass bug mentioned earlier that causes this to hang.
                    # So instead, we'll just use good old native Invoke-WebRequest for now.
                    $currentProgressPreference = $ProgressPreference

                    try {
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -usebasicparsing -Method GET -Uri $schemaUri -ErrorAction Stop |
                          Select-Object -ExpandProperty Content
                    } finally {
                        # Invoke-WebRequest on desktop does not support the ProgressAction parameter, so we reset
                        # the preference variable as a workaround. If progress is enabled, there are significant performance
                        # penalties for Invoke-WebRequest.
                        $ProgressPreference = $currentProgressPreference
                    }
                }

                write-debug "Finished reading schema content"
                write-debug "Parsing schema content as XML"

                [xml] ( $schemaContent | out-string )

                write-debug "Completed parsing of schema content as XML"
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

