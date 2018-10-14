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

. (import-script GraphCache)

ScriptClass GraphManager {

    static {
        $cache = $null

        function __initialize {
            $this.cache = new-so GraphCache
            # Start an asynchronous load of the metadata unless this is disabled
            # This is only meant for user interactive sessions and should be
            # disabled if this module is used in background jobs
            if ( ! (get-variable -scope script -name '__poshgraph_no_auto_metadata' -erroraction silentlycontinue) ) {
                write-verbose "Asynchronously updating Graph metadata"
                UpdateGraph ($::.GraphContext |=> GetCurrent)
            } else {
                write-verbose "Found __poshgraph_no_auto_metadata variable, skipping Graph metadata update"
            }
        }

        function UpdateGraph($context, $metadata = $null, $wait = $false, $force = $false) {
            __GetGraph ($context |=> GetEndpoint) $context.version $metadata $wait $force $true | out-null

            $uriCache = $context |=> GetState uriCache
            if ( $uriCache ) {
                $uriCache.Clear() # Need to change this to handle async retrieval of new graph
            }
        }

        function GetMetadataStatus($context) {
            $this.cache |=> GetMetadataStatus $context.connection.GraphEndpoint.Graph $context.version
        }

        function GetGraph($context, $metadata = $null, $force = $false) {
             __GetGraph ($context |=> GetEndpoint) $context.version $metadata $true $force
        }

        function __GetGraph($endpoint, $apiVersion, $metadata, $wait = $false, $force = $false, $forceupdate = $false) {
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
