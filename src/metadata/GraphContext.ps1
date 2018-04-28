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

. (import-script ..\common\ProgressWriter)

ScriptClass GraphContext {
    $connection = $null
    $version = $null
    $id = $null

    function __initialize($connection, $version = 'v1.0') {
        $this.connection = $connection
        $this.version = $version
        $this.id = $this.scriptclass |=> GetContextId $connection $version
    }

    function GetGraphEndpoint {
        if ( $this.connection ) {
            $this.connection.GraphEndpoint.Graph
        } else {
            $null
        }
    }

    function GetMetadata {
        $endpoint = GetGraphEndpoint
        $metadataActivity = "Reading metadata for graph version '$($this.version)' from endpoint '$endpoint'"
        write-progress -id 1 -activity $metadataactivity -status "In progress"
        $metadata = invoke-graphrequest -connection $this.connection '$metadata' -version $this.version
        write-progress -id 1 -activity $metadataactivity -status "Complete" -completed
        $metadata
    }

    static {
        function GetContextId($connection, $version) {
            $endpoint = __GetGraphEndpoint $connection
            ("{0}:{1}" -f $endpoint, $version)
        }

        function __GetGraphEndpoint($connection) {
            if ( $connection -ne $null ) {
                $connection.GraphEndpoint.Graph
            } else {
                $null
            }
        }
    }
}
