# Copyright 2017, Adam Edwards
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


include-source "src/app/GraphContext"
include-source "src/app/GraphAuthenticationContext"

class GraphConnection {
    $Context
    $Connected = $false

    GraphConnection($graphType = 'msgraph', $authType = 'msa', $tenantName = $null, $altAppId = $null, $altEndpoint = $null, $altAuthority = $null) {
        $this.Context = new-object "GraphContext" -argumentlist ($graphType, $authtype, $tenantName, $altAppId, $altEndpoint, $altAuthority)
    }
}

function GraphConnection_Connect([GraphConnection] $_this) {
    if ( ! $_this.Connected ) {
        GraphAuthenticationContext_AcquireToken $_this.Context.AuthContext | out-null
        $_this.Connected = $true
    }
}

