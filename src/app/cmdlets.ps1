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

include-source "src/app/graph"

function Get-MSAAuthContext {
    [CmdletBinding()]
    param($alternateAppId = $null)

    $appId = $alternateAppId

    if ($appId -eq $null) {
        $appId = [GraphPublicEndpoint]::MSGraphAppId()
    }

    $authContext = [GraphAuthenticationContext]::new('msa', $appId, $null, $null, $null)
    $authContext
}

function Get-AADAuthContext {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] [string] $tenantName,
                                              $alternateAppId = $null,
                                              $altResourceAppIdUri = $null,
                                              $alternateAuthority = $null
    )

    $resourceAppIdUri = $altResourceAppIdUri

    if ($resourceAppIdUri -eq $null) {
        $resourceAppIdUri = [GraphPublicEndpoint]::AADGraphEndpoint()
    }

    $appId = $alternateAppId

    if ($appId -eq $null) {
        $appId = [GraphPublicEndpoint]::AADGraphAppId()
    }

    $authContext = [GraphAuthenticationContext]::new('aad', $appId,  $tenantName, $resourceAppIdUri, $alternateAuthority)

    $authContext
}

function New-GraphConnection($graphType = 'msgraph', $authtype = 'msa', $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
    [GraphConnection]::new($graphType, $authtype, $tenantName, $alternateAppId, $alternateEndpoint, $alternateAuthority)
}

function ConnectToGraph($defaultConnection = $null) {
    $connection = if ($defaultConnection -eq $null) {
        New-GraphConnection
    } else {
        $defaultConnection
    }

    $connection.Connect()
    $connection
}

function Get-GraphItem($itemRelativeUri, $connection = $null) {
    (ConnectToGraph $connection).Context.GetGraphAPIResponse($itemRelativeUri, $null)
}
