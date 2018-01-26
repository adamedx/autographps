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

. (import-script GraphRequest)
. (import-script GraphConnection)

function Get-GraphVersion {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0,parametersetname='GetVersionExistingConnection',mandatory=$true)]
        [parameter(position=0,parametersetname='GetVersionNewConnection', mandatory=$true)]
        [String] $Version,

        [switch] $Json,

        [parameter(parametersetname='ListVersionsExistingConnection',mandatory=$true)]
        [parameter(parametersetname='ListVersionsNewConnection',mandatory=$true)]
        [switch] $List,

        [parameter(parametersetname='GetVersionNewConnection')]
        [parameter(parametersetname='ListVersionsNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ListVersionsExistingConnection', mandatory=$true)]
        [parameter(parametersetname='GetVersionExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    $graphConnection = if ( $Connection -eq $null ) {
        $::.GraphConnection |=> NewSimpleConnection ([GraphType]::MSGraph) $Cloud 'User.Read'
    } else {
        $Connection
    }

    $relativeBase = 'versions'
    $relativeUri = if ( ! $List.ispresent ) {
        $relativeBase, $version -join '/'
    } else {
        $relativeBase
    }

    $request = new-so GraphRequest $graphConnection $relativeUri GET
    $response = $request |=> Invoke

    if ( $JSON.ispresent ) {
        $response |=> Content
    } else {
        [PSCustomObject] $response.entities
    }
}
