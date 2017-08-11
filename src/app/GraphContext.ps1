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

include-source "src/app/GraphAuthenticationContext"

class GraphContext {
    $AuthContext
    $Endpoint
    $GraphType

    static [string] GetGraphEndpoint($graphType, $alternateEndpoint) {
        [GraphContext]::ValidateGraphType($graphType)
        $result = if ( $alternateEndpoint -ne $null ) {
            $alternateEndpoint
        } elseif ( $graphType -eq 'msgraph' ) {
            [GraphContext]::MSGraphEndpoint()
        } else {
            [GraphContext]::AADGraphEndpoint()
        }
        return $result
    }

    static [string] AADGraphEndpoint() {
        return "https://graph.windows.net"
    }

    static [string] MSGraphEndpoint() {
        return "https://graph.microsoft.com/v1.0"
    }

    static [string] AADGraphAppId() {
        return "42c41bc4-75da-4142-91d7-baf15cc24fb9"
    }

    static [string] MSGraphAppId() {
        return "01e45b18-f1e5-4e66-b2db-09ce7909b99d"
    }

    static [string] GetTenantEndpointComponent($graphType, $endpointRoot, $tenantName) {
        $result = if ($graphType -eq 'adgraph') {
            if ( $tenantName -eq $null) {
                throw "No tenant was specified for the ad graph endpoint"
            }
            $endpointRoot + "/$tenantName"
        } else {
            $endpointRoot
        }

        return $result
    }

    static [string] GetUriQueryComponent($graphType, $query = $null) {
        $result = ""
        $querySeparator = '?'
        if ($graphType -eq 'adgraph') {
            $result = "?api-version=1.6"
            $querySeparator = '&'
        }

        if ($query -ne $null) {
            $result += ($querySeparator + $query)
        }

        return $result
    }

    static [string] RestAPIResourceUri($endpoint, $resource, $query) {
        $strictUri = "$endpoint/$resource"

        $result = if ($query -eq $null) {
            $strictUri
        } else {
            "$($strictUri)$($query)"
        }

        return $result
    }

    static [string] RestAPIResourceUriForGraph($graphType, $endpointRoot, $tenantName, $resource, $query) {
        $graphEndpoint = [GraphContext]::GetTenantEndpointComponent($graphType, $endpointRoot, $tenantName)
        $queryComponent = [GraphContext]::GetUriQueryComponent($graphType, $query)
        return [GraphContext]::RestAPIResourceUri($graphEndpoint, $resource, $queryComponent)
    }

    InitializeGraphType($graphType) {
        [GraphContext]::ValidateGraphType($graphType)
        $this.GraphType = $graphType
    }

    GraphContext($graphType = 'msgraph', $authContext) {
        $this.Endpoint = $null
        $this.AuthContext = $authContext
        $this.InitializeGraphType($graphType)
    }

    GraphContext($graphType = 'msgraph', $authType = 'msa',  $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
        $this.InitializeGraphType($graphType)
        $this.Endpoint = [GraphContext]::GetGraphEndpoint($graphType, $alternateEndpoint)
        $this.InitializeAuth($graphType, $authType, $tenantName, $alternateAppId, $alternateEndpoint, $alternateAuthority)
    }

    static ValidateGraphType($graphType) {
        $validGraphs = @('msgraph', 'adgraph')
        if (-not $graphType -in $validGraphs) {
            throw "Invalid graph type '$graphType' was specified -- must be one of '$($validGraphs -join ',')'"
        }
    }
    InitializeAuth($graphType = 'msgraph', $authType = 'msa', $tenantName = $null, $altAppId = $null, $altEndpoint, $altAuthority = $null) {
        $resourceAppIdUri = if ($authType -eq 'aad') {
            [GraphContext]::GetGraphEndpoint($graphType, $altEndpoint)
        } else {
            $null
        }

        $appId = $altAppId

        if ($appId -eq $null) {
            $appId = if ($graphType -eq 'adgraph') {
                [GraphContext]::AADGraphAppId()
            } else {
                [GraphContext]::MSGraphAppId()
            }
        }

        $this.AuthContext = [GraphAuthenticationContext]::new($authType, $appId, $tenantName, $resourceAppIdUri, $altAuthority)
    }

    [object] InvokeRestAPIMethod($uri, $header, $method="GET") {
        $result = try {
            Invoke-RestMethod -Uri $uri -Headers $header -method $method
        } catch {
            write-error $_.Exception
            $_.Exception.Response | out-host
            $null
        }
        return $result
    }

    [object] GetRestAPIHeader($token) {
        # Building Rest Api header with authorization token
        return @{
            'Content-Type'='application\json'
            'Authorization'=$token.CreateAuthorizationHeader()
        }
    }

    [object] CallRestAPIMethodForResource($uri, $restAPIHeader) {
        return $this.InvokeRestAPIMethod($uri, $restAPIHeader, "GET")
    }

    [object] GetRestAPIResponseForResource($resourceUri, $token, $query = $null) {
        $restAPIHeader = $this.GetRestAPIHeader($token)
        $uri = [GraphContext]::RestAPIResourceUriForGraph($this.GraphType, $this.Endpoint, $this.AuthContext.TenantName, $resourceUri, $query)
       return $this.CallRestAPIMethodForResource($uri, $restAPIHeader)
    }

    [object] GetGraphAPIResponse($relativeResourceUri, $query = $null) {
        return $this.GetRestAPIResponseForResource($relativeResourceUri, $this.AuthContext.Token, $query)
    }
}
