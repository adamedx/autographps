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

. (import-script GraphConnection)
. (import-script GraphContext)
. (import-script New-GraphConnection)

function Connect-Graph {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='simple', position=0)]
        [parameter(parametersetname='custom', position=0)]
        [String[]] $ScopeNames = @('User.Read'),

        [parameter(parametersetname='simple')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='custom',mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    $context = $::.GraphContext |=> GetCurrent

    if ( ! $context ) {
        throw "No current session -- unable to connect it to Graph"
    }

    if ( $Connection -ne $null ) {
        write-verbose "Explicit connection was specified"
        $newContext = new-so GraphContext $connection $context.version
        $existingContext = 'GraphContext' |::> Get $newContext.name

        $context = if ( $existingContext ) {
            write-verbose
            $existingContext
        } else {
            $::.GraphContext |=> Add $newContext
            $newContext
        }

        $::.GraphContext |=> SetCurrentByName $context.name
    } else {
        $newConnection = new-graphconnection -graphendpointuri $context.connection.graphendpoint.graph -authenticationendpointuri $context.connection.graphendpoint.Authentication -appid $::.Application.AppId
        $context |=> Update $newConnection.identity $ScopeNames '/'
        $context.Connection |=> Connect
    }
}
