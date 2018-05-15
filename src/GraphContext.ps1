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
. (import-script LogicalGraphManager)
. (import-script metadata/GraphSegment)

ScriptClass GraphContext {
    $connection = $null
    $version = $null
    $name = $null
    $location = $null

    function __initialize($connection, $apiversion, $name) {
        if ( ! $name ) {
            throw "Graph name must be specified"
        }

        $graphConnection = $this.scriptclass |=> GetConnection $connection $null
        $graphVersion = if ( $apiVersion ) { $apiVersion } else { $this.scriptclass |=> GetDefaultVersion }

        $this.connection = $graphConnection
        $this.version = $graphVersion
        $this.name = $name
        $this.location = $::.GraphSegment.RootSegment
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

    function Update($identity, $scope) {
        if ($identity) {
            $newConnection = new-so GraphConnection $this.Connection.GraphEndpoint $identity $scope
            $this.connection = $newConnection
        }
    }

    function SetLocation([PSCustomObject] $location) {
        $this.location = $location
    }

    static {
        $current = $null
        $cache = $null

        function __initialize {
            $::.LogicalGraphManager |=> __initialize
            $currentContext = $::.LogicalGraphManager |=> Get |=> NewContext $null (__GetSimpleConnection ([GraphType]::MSGraph)) (GetDefaultVersion) 'Default'
            $this.current = $currentContext.Name
            $this.cache = new-so GraphCache

            # Start an asynchronous load of the metadata unless this is disabled
            # This is only meant for user interactive sessions and should be
            # disabled if this module is used in background jobs
            if ( ! (get-variable -scope script -name '__poshgraph_no_auto_metadata' -erroraction silentlycontinue) ) {
                write-verbose "Asynchronously updating Graph metadata"
                $currentContext |=> UpdateGraph
            } else {
                write-verbose "Found __poshgraph_no_auto_metadata variable, skipping Graph metadata update"
            }
        }

        function GetCurrent  {
            if ( $this.current ) {
                write-verbose "Attempt to get current context -- current context is set to '$($this.current)'"
                $::.LogicalGraphManager |=> Get |=> GetContext $this.current
            } else {
                write-verbose "Attempt to get current context -- no context is currently set"
            }
        }

        function SetCurrentByName($name) {
            if ( ! ($::.LogicalGraphManager |=> Get |=> GetContext $name) ) {
                throw "No such context: '$name'"
            }

            write-verbose "Setting current context to '$name'"
            $this.current = $name
        }

        function GetCurrentConnection {
            $context = GetCurrent
            if ( $context ) {
                $context.connection
            }
        }

        function DisconnectCurrentConnection {
            $context = GetCurrent
            if ( $context ) {
                $context.connection |=> Disconnect
            } else {
                throw "Cannot disconnect the current context from Graph because there is no current context."
            }
        }

        function GetDefaultVersion {
            'v1.0'
        }

        function __IsContextConnected($context) {
            $context -and ($context.connection |=> IsConnected)
        }

        function __GetSimpleConnection([GraphCloud] $graphType, [GraphCloud] $cloud = 'Public', [String[]] $ScopeNames, $anonymous = $false) {
            write-verbose "Connection request for Graph = '$graphType', Cloud = '$cloud', Anonymous = $($anonymous -eq $true)"
            if ( $scopenames ) {
                write-verbose "Scopes requested:"
                $scopenames | foreach {
                    write-verbose "`t$($_)"
                }
            } else {
                write-verbose "No scopes requested"
            }

            $currentContext = GetCurrent

            $sessionConnection = GetCurrentConnection
            if ( $graphType -eq [GraphType]::AADGraph -or ! (__IsContextConnected $currentContext) -or (! $anonymous -and ! $sessionConnection.identity)) {
                $::.GraphConnection |=> NewSimpleConnection $graphType $cloud $ScopeNames $anonymous
            } else {
                $sessionConnection
            }
        }

        function GetConnection($connection = $null, $context = $null, $cloud = $null, [String[]] $scopenames = $null, $anonymous = $null) {
            $currentContext = GetCurrent

            $existingConnection = if ( $connection ) {
                write-verbose "Using supplied connection"
                $connection
            } elseif ( $context ) {
                write-verbose "Using connection from supplied context '$($context.name)'"
                $context.connection
            } elseif ( $currentContext ) {
                write-verbose "Found existing connection from current context '$($currentcontext.name)'"
                if ( ( ! $cloud -or $currentContext.cloud -eq $cloud) -and
                     ! ($scopenames -eq 'User.Read' -or ($scopenames -is [String[]] -and $scopenames.length -eq 1 -and $scopenames[0] -eq 'User.Read' )) -and
                     ! $anonymous
                   ) {
                       write-verbose "Current context is compatible with supplied arguments, will use it"
                       $currentContext
                   } else {
                       write-verbose "Current context is not compatible with supplied arguments, new connection required"
                   }
            }

            if ( $existingConnection ) {
                write-verbose "Using an existing connection supplied directly or obtained through a context"
                $existingConnection
            } else {
                write-verbose "No connection supplied and no compatible connection found from a context"
                $namedArguments=@{Anonymous=($anonymous -eq $true)}
                if ( $cloud ) { $namedArguments['Cloud'] = $cloud }
                if ( $scopenames ) { $namedArguments['ScopeNames'] = $scopenames }

                write-verbose "Custom arguments or no current context -- getting a new connection"
                $newConnection = __GetSimpleConnection ([GraphType]::MSGraph) @namedArguments
                $newConnection
            }
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

$::.GraphContext |=> __initialize

