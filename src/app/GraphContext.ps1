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

function GraphContext($method = $null) {

    class GraphContext {
        $AuthContext
        $Endpoint
        $GraphType

        GraphContext($graphType = 'msgraph', $authContext) {
            $this.Endpoint = $null
            $this.AuthContext = $authContext
            InitializeGraphType $this $graphType
        }

        GraphContext($graphType = 'msgraph', $authType = 'msa',  $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
            InitializeGraphType $this $graphType
            $this.Endpoint = GetGraphEndpoint $graphType $alternateEndpoint
            InitializeAuth $this $graphType $authType $tenantName $alternateAppId $alternateEndpoint $alternateAuthority
        }
    }

    function GetRestAPIResponseForResource($_this, $resourceUri, $token, $query = $null) {
        $restAPIHeader = GetRestAPIHeader $token
        $uri = RestAPIResourceUriForGraph $_this.GraphType $_this.Endpoint $_this.AuthContext.TenantName $resourceUri $query
        CallRestAPIMethodForResource $uri $restAPIHeader
    }

    function GetGraphAPIResponse($_this, $relativeResourceUri, $query = $null) {
        GetRestAPIResponseForResource $_this $relativeResourceUri $_this.AuthContext.Token $query
    }

    function CallRestAPIMethodForResource($uri, $restAPIHeader) {
        InvokeRestAPIMethod $uri $restAPIHeader "GET"
    }

    function InvokeRestAPIMethod($uri, $header, $method="GET") {
        $result = try {
            Invoke-RestMethod -Uri $uri -Headers $header -method $method
        } catch {
            write-error $_.Exception
            $_.Exception.Response | out-host
            $null
        }

        $result
    }

    function GetGraphEndpoint($graphType, $alternateEndpoint) {
        ValidateGraphType $graphType
        $result = if ( $alternateEndpoint -ne $null ) {
            $alternateEndpoint
        } elseif ( $graphType -eq 'msgraph' ) {
            (MSGraphEndpoint)
        } else {
            (AADGraphEndpoint)
        }
        $result
    }

    function AADGraphEndpoint() {
        "https://graph.windows.net"
    }

    function MSGraphEndpoint() {
        "https://graph.microsoft.com/v1.0"
    }

    function AADGraphAppId() {
        "42c41bc4-75da-4142-91d7-baf15cc24fb9"
    }

    function MSGraphAppId() {
        "01e45b18-f1e5-4e66-b2db-09ce7909b99d"
    }

    function GetTenantEndpointComponent($graphType, $endpointRoot, $tenantName) {
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

    function GetUriQueryComponent($graphType, $query = $null) {
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

    function RestAPIResourceUri($endpoint, $resource, $query) {
        $strictUri = "$endpoint/$resource"

        $result = if ($query -eq $null) {
            $strictUri
        } else {
            "$($strictUri)$($query)"
        }

        $result
    }

    function RestAPIResourceUriForGraph($graphType, $endpointRoot, $tenantName, $resource, $query) {
        $graphEndpoint = GetTenantEndpointComponent $graphType $endpointRoot $tenantName
        $queryComponent = GetUriQueryComponent $graphType $query
        RestAPIResourceUri $graphEndpoint $resource $queryComponent
    }

    function ValidateGraphType($graphType) {
        $validGraphs = @('msgraph', 'adgraph')
        if (-not $graphType -in $validGraphs) {
            throw "Invalid graph type '$graphType' was specified -- must be one of '$($validGraphs -join ',')'"
        }
    }

    function InitializeAuth($_this, $graphType = 'msgraph', $authType = 'msa', $tenantName = $null, $altAppId = $null, $altEndpoint, $altAuthority = $null) {
        $resourceAppIdUri = if ($authType -eq 'aad') {
            GetGraphEndpoint $graphType $altEndpoint
        } else {
            $null
        }

        $appId = $altAppId

        if ($appId -eq $null) {
            $appId = if ($graphType -eq 'adgraph') {
                (AADGraphAppId)
            } else {
                (MSGraphAppId)
            }
        }

        $_this.AuthContext = GraphAuthenticationContext __new $authType $appId $tenantName $resourceAppIdUri $altAuthority
    }

    function GetRestAPIHeader($token) {
        # Building Rest Api header with authorization token
        @{
            'Content-Type'='application\json'
            'Authorization'=$token.CreateAuthorizationHeader()
        }
    }

    function InitializeGraphType($_this, $graphType) {
        ValidateGraphType $graphType
        $_this.GraphType = $graphType
    }

    . $define_class @args
}


