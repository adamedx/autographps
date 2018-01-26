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

. (import-script New-GraphConnection)

function Get-GraphToken {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='aadgraph', mandatory=$true)][parameter(parametersetname='custom')][switch] $AADGraph,
        [parameter(parametersetname='msgraph')][String[]] $ScopeNames = @('User.Read'),
        [parameter(parametersetname='msgraph')] [GraphCloud] $Cloud = [GraphCloud]::Public,
        [parameter(parametersetname='msgraph')][parameter(parametersetname='custom',mandatory=$true)][Guid] $AppId,
        [parameter(parametersetname='msgraph')][parameter(parametersetname='custom')][Guid] $AppIdSecret,
        [parameter(parametersetname='custom', mandatory=$true)][Uri] $GraphEndpointUri = $null,
        [parameter(parametersetname='custom', mandatory=$true)][Uri] $AuthenticationEndpointUri = $null
    )
    $connectionArguments = @{}
    $psboundparameters.keys | foreach {
        $connectionArguments[$_] = $psboundparameters[$_]
    }

    $connection = New-GraphConnection @connectionArguments
    $connection |=> Connect

    $connection.Identity.Token.AccessToken
}
