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

. (import-script GraphCache)

ScriptClass GraphManager {

    static {
        $cache = $null

        const TimeStateKey TimeData
        const UriCacheStateKey UriCache
        const TypeStateKey TypeManager
        const MetadataSourceStateKey MetadataSource

        function __initialize {
            $this.cache = new-so GraphCache
            # Start an asynchronous load of the metadata unless this is disabled
            # This is only meant for user interactive sessions and should be
            # disabled if this module is used in background jobs
            if ( ! (get-variable -scope script -name '__poshgraph_no_auto_metadata' -erroraction ignore) ) {
                write-verbose "Asynchronously updating Graph metadata"
                UpdateGraph ($::.GraphContext |=> GetCurrent)
            } else {
                write-verbose "Found __poshgraph_no_auto_metadata variable, skipping Graph metadata update"
            }
        }

        function UpdateGraph($context, $metadata = $null, $wait = $false, $force = $false, $metadataSourceOverridePath) {
            $graphEndpoint = $context |=> GetEndpoint
            $graph =__GetGraph $graphEndpoint $context.version $metadata $wait $force $true
            $uriCache = $context |=> GetState $this.UriCacheStateKey
            if ( $uriCache ) {
                $uriCache.Clear() # Need to change this to handle async retrieval of new graph
            }

            $typeManager = $context |=> GetState $this.TypeStateKey

            if ( $typeManager ) {
                $::.TypeProvider |=> RemoveTypeProvidersForGraph $graph
                $context |=> RemoveState $this.TypeStateKey
            }

            $updateTime = [DateTimeOffset]::Now
            $timeData = $context |=> GetState $this.TimeStateKey

            if ( $timeData ) {
                $timeData.UpdatedTime = $updateTime
            } else {
                $timeData = [PSCustomObject] @{
                    CreatedTime = $updateTime
                    UpdatedTime = $updateTime
                }
            }

            $context |=> SetState $this.TimeStateKey $timeData

            $updateSource = if ( $metadataSourceOverridePath ) {
                $metadataSourceOverridePath
            } else {
                $graphEndpoint.tostring().trimend('/'), $context.version, '$metadata' -join '/'
            }

            $context |=> SetState $this.MetadataSourceStateKey $updateSource
        }

        function GetMetadataStatus($context) {
            # See comments in __GetGraph about the still unknown need for this
            if ( ! $this.cache ) {
                __initialize
            }

            $this.cache |=> GetMetadataStatus $context.connection.GraphEndpoint.Graph $context.version
        }

        function GetGraph($context, $metadata = $null, $force = $false) {
             __GetGraph ($context |=> GetEndpoint) $context.version $metadata $true $force
        }

        function __GetGraph($endpoint, $apiVersion, $metadata, $wait = $false, $force = $false, $forceupdate = $false) {
            # This really should not be necessary since __initialize is called at the script level, but there
            # seems to be an issue when executing in automated CI where class members are not initialized,
            # possibly due to some inability to call __initialize at some point -- we call it here if we detect
            # uninitalized state and this seems to "fix" the CI.
            if ( ! $this.cache ) {
                __initialize
            }

            if ( $Force ) {
                $this.cache |=> CancelPendingGraph $endpoint $apiVersion
            }

            if ( $wait -and ! $forceupdate ) {
                $this.cache |=> GetGraph $endpoint $apiVersion $metadata
            } else {

                $asyncResult = $this.cache |=> GetGraphAsync $endpoint $apiVersion $metadata

                if ( $wait ) {
                    $this.cache |=> WaitForGraphAsync $asyncResult
                } else {
                    $asyncResult
                }
            }
        }
    }
}

$::.GraphManager |=> __initialize
