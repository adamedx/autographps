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

. (import-script ../GraphService/GraphEndpoint)
. (import-script ../Client/GraphIdentity)
. (import-script ../Client/GraphConnection)

function New-GraphConnection {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='aadgraph', mandatory=$true)]
        [parameter(parametersetname='custom')]
        [switch] $AADGraph,

        [parameter(parametersetname='msgraph')]
        [parameter(parametersetname='custom')]
        [String[]] $ScopeNames = @('User.Read'),

        [parameter(parametersetname='msgraph')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='custom')]
        [Guid] $AppId,

        [parameter(parametersetname='msgraph')]
        [parameter(parametersetname='custom')]
        [Guid] $AppIdSecret,

        [parameter(parametersetname='msgraph')]
        [parameter(parametersetname='custom', mandatory=$true)]
        [Uri] $GraphEndpointUri = $null,

        [parameter(parametersetname='msgraph')]
        [parameter(parametersetname='custom', mandatory=$true)]
        [Uri] $AuthenticationEndpointUri = $null
    )

    $graphType = if ( $AADGraph.ispresent ) {
        ([GraphType]::AADGraph)
    } else {
        ([GraphType]::MSGraph)
    }

    if ( $GraphEndpointUri -eq $null -and $AuthenticationEndpointUri -eq $null ) {
        $::.GraphConnection |=> NewSimpleConnection $graphType $Cloud $ScopeNames
    } else {
        $graphEndpoint = if ( $GraphEndpointUri -eq $null ) {
            new-so GraphEndpoint $Cloud $graphType
        } else {
            new-so GraphEndpoint ([GraphCloud]::Unknown) ([Graphtype]::MSGraph) $GraphEndpointUri $AuthenticationEndpointUri
        }

        $app = new-so GraphApplication $AppId
        $identity = new-so GraphIdentity $app
        new-so GraphConnection $graphEndpoint $identity $ScopeNames
    }
}
