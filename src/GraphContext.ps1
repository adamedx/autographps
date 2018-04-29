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
. (import-script GraphConnection)

ScriptClass GraphContext {
    $connection = $null
    $version = $null
    $id = $null
    $name = $null

    function __initialize($connection, $apiversion = 'v1.0', $name = $null) {
        $version = if ( $apiVersion ){
            $apiVersion
        } else {
            'v1.0'
        }
        $this.connection = if ( $connection ) {
            $connection
        } else {
            $::.GraphConnection |=> GetDefaultConnection ([GraphType]::MSGraph) -anonymous $true
        }
        $this.version = $version
        $this.id = $this.scriptclass |=> __GetContextId (GetEndpoint) $version
        $this.name = if ( $name ) {
            $name
        } else {
            $this.scriptclass |=> __GetDefaultNameFromId $this.id
        }
    }

    function UpdateGraph($metadata = $null, $wait = $false, $force = $false) {
        $this.scriptclass |=> __GetGraph (GetEndpoint) $this.version $metadata $wait $force $true | out-null
    }

    function GetGraph($metadata = $null, $force = $false) {
        $this.scriptclass |=> __GetGraph (GetEndpoint) $this.version $metadata $true $force
    }

    function GetEndpoint {
        $this.connection.GraphEndpoint.Graph
    }

    static {
        $contexts = $null
        $default = $null
        $cache = $null

        function __initialize {
            $this.contexts = @{}
            $defaultContext = new-so GraphContext $null $null 'Default'
            $this.default = $defaultContext.Name
            $this.cache = new-so GraphCache
            __Add $defaultContext

            # Start an asynchronous load of the metadata unless this is disabled
            # This is only meant for user interactive sessions and should be
            # disabled if this module is used in background jobs
            if ( ! (get-variable -scope script -name '__poshgraph_no_auto_metadata' -erroraction silentlycontinue ) ) {
                write-verbose "Asynchronously updating Graph metadata"
                $defaultContext |=> UpdateGraph
            } else {
                write-verbose "Found __poshgraph_no_auto_metadata variable, skipping Graph metadata update"
            }
        }

        function NewContext($connection, $version = 'v1.0', $name = $null) {
            $context = new-so $this.classname $connection $version $name
            __Add $context
            $context
        }

        function GetFromConnection($connection, $version = 'v1.0') {
            $graphConnection = if ( $connection ) {
                $connection
            } else {
                $::.GraphConnection |=> GetDefaultConnection ([GraphType]::MSGraph) -anonymous $true
            }

            $contextId = __GetContextId $graphConnection.GraphEndpoint.Graph $version
            $defaultName = __GetDefaultNameFromId $contextId
            $context = $this.contexts[$defaultName]

            if ( $context ) {
                $context
            } else {
                NewContext $connection $version $defaultName
            }
        }

        function Get($name) {
            $this.contexts[$name]
        }

        function GetDefault($version)  {
            if ( $this.default ) {
                $defaultContext = $this.contexts[$this.default]
                if ( ! $version -or $defaultContext.version -eq $version ) {
                    $defaultContext
                } else {
                    GetDefaultFromConnection $defaultContext.connection $version
                }
            }
        }

        function GetAll {
            $this.contexts.clone()
        }

        function SetDefaultByName($name) {
            if ( ! $this.Get($name) ) {
                throw "No such context: '$name'"
            }

            $this.default = $name
        }

        function __Add($context) {
            if ( $this.Get($context.name) ) {
                throw "Context '$name' already exists"
            }

            __Set $context
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

        function __Set($context) {
            $this.contexts[$context.name] = $context
        }

        function __GetContextId([Uri] $endpoint, $apiversion) {
            new-object Uri $endpoint, $apiversion, $false
        }

        function __GetDefaultNameFromId([Uri] $contextId) {
            "{0}:{1}" -f $contextId.host, $version
        }
    }
}

$::.GraphContext |=> __initialize

