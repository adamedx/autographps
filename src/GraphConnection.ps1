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

. (import-script Application)
. (import-script GraphEndpoint)
. (import-script GraphIdentity)

enum GraphConnectionStatus {
    Online
    Offline
}

ScriptClass GraphConnection {
    $Identity = $null
    $GraphEndpoint = $null
    $Scopes = $null
    $Connected = $false
    $Status = [GraphConnectionStatus]::Online

    function __initialize([PSCustomObject] $graphEndpoint, [PSCustomObject] $Identity, [Object[]]$Scopes) {
        $this.GraphEndpoint = $graphEndpoint
        $this.Identity = $Identity
        $this.Connected = $false
        $this.Status = [GraphConnectionStatus]::Online

        if ( $this.GraphEndpoint.Type -eq ([GraphType]::MSGraph) ) {
            if ( $Identity -and ! $scopes ) {
                throw "No scopes were specified, at least one scope must be specified"
            }
            $this.Scopes = $Scopes
        }
    }

    function Connect {
        if ( ! $this.connected ) {
            if ($this.Identity) {
                $this.Identity |=> Authenticate $this.GraphEndpoint $this.Scopes
            }
            $this.connected = $true
        }
    }

    function SetStatus( [GraphConnectionStatus] $status ) {
        $this.Status = $status
    }

    function Disconnect {
        if ( $this.connected ) {
            $this.identity |=> ClearAuthentication
            $this.connected = $false
        } else {
            throw "Cannot disconnect from Graph because connection is already disconnected."
        }
    }

    function IsConnected {
        $this.connected
    }

    static {
        function NewSimpleConnection([GraphType] $graphType, [GraphCloud] $cloud = 'Public', [String[]] $ScopeNames, $anonymous = $false) {
            $endpoint = new-so GraphEndpoint $cloud $graphType
            $app = new-so GraphApplication $::.Application.AppId
            $identity = if ( ! $anonymous ) {
                new-so GraphIdentity $app
            }

            new-so GraphConnection $endpoint $identity $ScopeNames
        }
    }
}
