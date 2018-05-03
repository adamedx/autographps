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
    $url = $null

    function __initialize($connection, $apiversion = $null, $name = $null) {
        $graphConnection = $this.scriptclass |=> GetConnection $connection $null -anonymous $true
        $graphVersion = $this.scriptclass |=> GetVersion $apiVersion

        $this.connection = $graphConnection
        $this.version = $graphVersion
        $this.id = $this.scriptclass |=> __GetContextId (GetEndpoint) $apiversion
        $this.name = if ( $name ) {
            $name
        } else {
            $this.scriptclass |=> __GetDefaultNameFromId $this.id $graphVersion
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

    function Update($identity, $scopes, $location) {
        if ($identity) {
            $newConnection = new-so GraphConnection $this.Connection.GraphEndpoint $identity $scopes
            $this.connection = $newConnection
        }

        if ($location) {
            $this.url = $location
        }
    }

    static {
        $contexts = $null
        $current = $null
        $cache = $null

        function __initialize {
            $this.contexts = @{}
            $currentContext = new-so GraphContext $null $null 'Default'
            $this.current = $currentContext.Name
            $this.cache = new-so GraphCache
            __Add $currentContext

            # Start an asynchronous load of the metadata unless this is disabled
            # This is only meant for user interactive sessions and should be
            # disabled if this module is used in background jobs
            if ( ! (get-variable -scope script -name '__poshgraph_no_auto_metadata' -erroraction silentlycontinue ) ) {
                write-verbose "Asynchronously updating Graph metadata"
                $currentContext |=> UpdateGraph
            } else {
                write-verbose "Found __poshgraph_no_auto_metadata variable, skipping Graph metadata update"
            }
        }

        function Get($name) {
            $this.contexts[$name]
        }

        function GetCurrent  {
            if ( $this.current ) {
                write-verbose "Attempt to get current context -- current context is set to '$($this.current)'"
                Get $this.current
            } else {
                write-verbose "Attempt to get current context -- no context is currently set"
            }
        }

        function GetAll {
            $this.contexts.clone()
        }

        function SetCurrentByName($name) {
            if ( ! $this.Get($name) ) {
                throw "No such context: '$name'"
            }

            write-verbose "Setting current context to '$name'"
            $this.current = $name
        }

        function GetVersion($version, $context) {
            if ( $version ) {
                $version
            } else {
                $versionContext = if ( $context ) {
                    $context
                } else {
                    GetCurrent
                }

                if ( $versionContext) {
                    $versionContext.version
                } else {
                    'v1.0'
                }
            }
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

        function Add($context) {
            __Add $context
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
            $this.contexts.Add($context.name, $context)
        }

        function __GetContextId([Uri] $endpoint, $apiversion) {
            new-object Uri $endpoint, $apiversion, $false
        }

        function __GetDefaultNameFromId([Uri] $contextId, $version) {
            "{0}:{1}" -f $contextId.host, $version
        }
    }
}

$::.GraphContext |=> __initialize

