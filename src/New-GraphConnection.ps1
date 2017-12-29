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

. (import-script GraphEndpoint)
. (import-script GraphIdentity)
. (import-script GraphConnection)
. (import-script Application)

function New-GraphConnection {
    [cmdletbinding()]
    param(
        [parameter(parametersetname='aadgraph', mandatory=$true)][parameter(parametersetname='custom')][switch] $AADGraph,
        [parameter(parametersetname='aadgraph', mandatory=$true)][parameter(parametersetname='msgraph')] [parameter(parametersetname='custom')] $AADTenantId,
        [parameter(parametersetname='msgraph')] [GraphCloud] $Cloud = [GraphCloud]::Public,
        [parameter(parametersetname='msgraph')] [IdentityType] $AccountType = ([IdentityType]::MSA),
        [parameter(parametersetname='msgraph')][parameter(parametersetname='custom',mandatory=$true)][Guid] $AppId,
        [parameter(parametersetname='msgraph')][parameter(parametersetname='custom')][Guid] $AppIdSecret,
        [parameter(parametersetname='custom', mandatory=$true)][Uri] $GraphEndpointUri = $null,
        [parameter(parametersetname='custom', mandatory=$true)][Uri] $AuthenticationEndpointUri = $null
    )

    $graphAccountType = $AccountType
    $graphType = if ( $AADGraph.ispresent ) {
        ([GraphType]::AADGraph)
        $defaultVersion = '1.6'
        $graphAccountType = ([IdentityType]::AAD)
    } else {
        ([GraphType]::MSGraph)
        $defaultVersion = '1.0'
    }

    if ( $GraphEndpointUri -eq $null -and $AuthenticationEndpointUri -eq $null ) {
        $::.GraphConnection |=> NewSimpleConnection $graphType $AADTenantId $Cloud
    } else {
        $graphEndpoint = if ( $GraphEndpointUri -eq $null ) {
            new-so GraphEndpoint $Cloud $graphType
        } else {
            new-so GraphEndpoint $GraphEndpointUri $AuthenticationEndpointUri
        }

        $app = new-so GraphApplication $connectionAppId
        $identity = new-so GraphIdentity $app $graphAccountType $TenantId
        new-so GraphConnection $graphEndpoint $identity
    }
}
