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

    GraphContext($graphType = 'msgraph', $authContext) {
        $this.Endpoint = $null
        $this.AuthContext = $authContext
        GraphContext_InitializeGraphType $this $graphType
    }

    GraphContext($graphType = 'msgraph', $authType = 'msa',  $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
        GraphContext_InitializeGraphType $this $graphType
        $this.Endpoint = GraphContext_GetGraphEndpoint $graphType $alternateEndpoint
        GraphContext_InitializeAuth $this $graphType $authType $tenantName $alternateAppId $alternateEndpoint $alternateAuthority
    }
}

function GraphContext_InitializeGraphType([GraphContext] $_this, $graphType) {
    GraphContext_ValidateGraphType $graphType
    $_this.GraphType = $graphType
}

function GraphContext_GetRestAPIResponseForResource([GraphContext] $_this, $resourceUri, $token, $query = $null) {
    $restAPIHeader = GraphContext_GetRestAPIHeader $token
    $uri = GraphContext_RestAPIResourceUriForGraph $_this.GraphType $_this.Endpoint $_this.AuthContext.TenantName $resourceUri $query
    GraphContext_CallRestAPIMethodForResource $uri $restAPIHeader
}

function GraphContext_GetGraphAPIResponse([GraphContext] $_this, $relativeResourceUri, $query = $null) {
    GraphContext_GetRestAPIResponseForResource $_this $relativeResourceUri $_this.AuthContext.Token $query
}

function GraphContext_CallRestAPIMethodForResource($uri, $restAPIHeader) {
    GraphContext_InvokeRestAPIMethod $uri $restAPIHeader "GET"
}

function GraphContext_InvokeRestAPIMethod($uri, $header, $method="GET") {
    $result = try {
        Invoke-RestMethod -Uri $uri -Headers $header -method $method
    } catch {
        write-error $_.Exception
        $_.Exception.Response | out-host
        $null
    }

    $result
}

function GraphContext_GetGraphEndpoint($graphType, $alternateEndpoint) {
    GraphContext_ValidateGraphType $graphType
    $result = if ( $alternateEndpoint -ne $null ) {
        $alternateEndpoint
    } elseif ( $graphType -eq 'msgraph' ) {
        (GraphContext_MSGraphEndpoint)
    } else {
        (GraphContext_AADGraphEndpoint)
    }
    $result
}

function GraphContext_AADGraphEndpoint() {
    "https://graph.windows.net"
}

function GraphContext_MSGraphEndpoint() {
    "https://graph.microsoft.com/v1.0"
}

function GraphContext_AADGraphAppId() {
    "42c41bc4-75da-4142-91d7-baf15cc24fb9"
}

function GraphContext_MSGraphAppId() {
    "01e45b18-f1e5-4e66-b2db-09ce7909b99d"
}

function GraphContext_GetTenantEndpointComponent($graphType, $endpointRoot, $tenantName) {
    $result = if ($graphType -eq 'adgraph') {
        if ( $tenantName -eq $null) {
            throw "No tenant was specified for the ad graph endpoint"
        }
        $endpointRoot + "/$tenantName"
    } else {
        $endpointRoot
    }

    $result
}

function GraphContext_GetUriQueryComponent($graphType, $query = $null) {
    $result = ""
    $querySeparator = '?'
    if ($graphType -eq 'adgraph') {
        $result = "?api-version=1.6"
        $querySeparator = '&'
    }

    if ($query -ne $null) {
        $result += ($querySeparator + $query)
    }

    $result
}

function GraphContext_RestAPIResourceUri($endpoint, $resource, $query) {
    $strictUri = "$endpoint/$resource"

    $result = if ($query -eq $null) {
        $strictUri
    } else {
        "$($strictUri)$($query)"
    }

    $result
}

function GraphContext_RestAPIResourceUriForGraph($graphType, $endpointRoot, $tenantName, $resource, $query) {
    $graphEndpoint = GraphContext_GetTenantEndpointComponent $graphType $endpointRoot $tenantName
    $queryComponent = GraphContext_GetUriQueryComponent $graphType $query
    GraphContext_RestAPIResourceUri $graphEndpoint $resource $queryComponent
}

function GraphContext_ValidateGraphType($graphType) {
    $validGraphs = @('msgraph', 'adgraph')
    if (-not $graphType -in $validGraphs) {
        throw "Invalid graph type '$graphType' was specified -- must be one of '$($validGraphs -join ',')'"
    }
}

function GraphContext_InitializeAuth([GraphContext] $_this, $graphType = 'msgraph', $authType = 'msa', $tenantName = $null, $altAppId = $null, $altEndpoint, $altAuthority = $null) {
    $resourceAppIdUri = if ($authType -eq 'aad') {
        GraphContext_GetGraphEndpoint $graphType $altEndpoint
    } else {
        $null
    }

    $appId = $altAppId

    if ($appId -eq $null) {
        $appId = if ($graphType -eq 'adgraph') {
            (GraphContext_AADGraphAppId)
        } else {
            (GraphContext_MSGraphAppId)
        }
    }

    $_this.AuthContext = [GraphAuthenticationContext]::new($authType, $appId, $tenantName, $resourceAppIdUri, $altAuthority)
}

function GraphContext_GetRestAPIHeader($token) {
    # Building Rest Api header with authorization token
    @{
        'Content-Type'='application\json'
        'Authorization'=$token.CreateAuthorizationHeader()
    }
}

