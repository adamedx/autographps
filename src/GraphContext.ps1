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

. (import-script GraphAuthenticationContext)

ScriptClass GraphContext {
    $AuthContext = $null
    $Endpoint = $null
    $GraphType = $null

    function __initialize($graphType = 'msgraph', $authType = 'msa',  $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
        InitializeGraphType $graphType
        $this.Endpoint = GetGraphEndpoint $graphType $alternateEndpoint
        InitializeAuth $graphType $authType $tenantName $alternateAppId $alternateEndpoint $alternateAuthority
    }

    function GetRestAPIResponseForResource($resourceUri, $token, $query = $null) {
        $restAPIHeader = GetRestAPIHeader $token
        $uri = RestAPIResourceUriForGraph $this.GraphType $this.Endpoint $this.AuthContext.TenantName $resourceUri $query
        CallRestAPIMethodForResource $uri $restAPIHeader
    }

    function GetGraphAPIResponse($relativeResourceUri, $query = $null) {
        GetRestAPIResponseForResource $relativeResourceUri $this.AuthContext.Token $query
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
        "9825d80c-5aa0-42ef-bf13-61e12116704c"
    }

    function MSGraphAppId() {
        "9825d80c-5aa0-42ef-bf13-61e12116704c"
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

    function InitializeAuth($graphType = 'msgraph', $authType = 'msa', $tenantName = $null, $altAppId = $null, $altEndpoint, $altAuthority = $null) {
        $resourceAppIdUri = if ($authType -eq 'aad') {
            GetGraphEndpoint $graphType $altEndpoint
        } else {
            $null
        }

        $appId = $altAppId

        if ($appId -eq $null) {
            $appId = if ($graphType -eq 'adgraph') {
#            $appId = if ($authType -eq 'aad') {
                (AADGraphAppId)
            } else {
                (MSGraphAppId)
            }
        }

        $this.AuthContext = new-scriptobject GraphAuthenticationContext $authType $appId $tenantName $resourceAppIdUri $altAuthority
    }

    function GetRestAPIHeader($token) {
        @{
            'Content-Type'='application\json'
            'Authorization'=$token.CreateAuthorizationHeader()
        }
    }

    function InitializeGraphType($graphType) {
        ValidateGraphType $graphType
        $this.GraphType = $graphType
    }
}


