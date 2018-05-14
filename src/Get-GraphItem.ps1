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

. (import-script Invoke-GraphRequest)

function Get-GraphItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true)]
    param(
        [parameter(position=0,mandatory=$true)]
        [Uri[]] $ItemRelativeUri,

        [parameter(position=1, parametersetname='MSGraphNewConnection')]
        [String[]] $ScopeNames = $null,

        [String] $Version = $null,

        [switch] $Json,

        [switch] $AbsoluteUri,

        [HashTable] $Headers = $null,

        [parameter(parametersetname='AADGraphNewConnection', mandatory=$true)]
        [switch] $AADGraph,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    $requestArguments = @{
        RelativeUri=$ItemRelativeUri
        Version=$Version
        JSON=$Json
        AbsoluteUri=$AbsoluteUri
        Headers=$Headers
        First=$pscmdlet.pagingparameters.first
        Skip=$pscmdlet.pagingparameters.skip
        IncludeTotalCount=$pscmdlet.pagingparameters.includetotalcount
    }

    if ( $AADGraph.ispresent ) {
        $requestArguments['AADGraph'] = $AADGraph
    } elseif ($ScopeNames -ne $null) {
        $requestArguments['ScopeNames'] = $ScopeNames
    }

    if ( $Connection -ne $null ) {
        $requestArguments['Connection'] = $Connection
    }

    Invoke-GraphRequest @requestArguments
}

