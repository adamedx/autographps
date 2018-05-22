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

. (import-script ../Invoke-GraphRequest)
. (import-script Get-GraphUri)

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true)]
    param(
        [parameter(position=0)]
        [Uri[]] $ItemRelativeUri = @('.'),

        [parameter(position=1, parametersetname='MSGraphNewConnection')]
        [String[]] $ScopeNames = $null,

        [String] $Version = $null,

        [switch] $Json,

        [switch] $AbsoluteUri,

        [HashTable] $Headers = $null,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    if ( $Version -or $Connection -or ($Cloud -ne ([GraphCloud]::Public)) ) {
        throw [NotImplementedException]::new("Non-default context not yet implemented")
    }

    $resolvedUri = Get-GraphUri $ItemRelativeUri[0]

    $results = @()

    $requestArguments = @{
        RelativeUri=$ItemRelativeUri[0]
        Version=$Version
        JSON=$Json
        AbsoluteUri=$AbsoluteUri
        Headers=$Headers
        First=$pscmdlet.pagingparameters.first
        Skip=$pscmdlet.pagingparameters.skip
        IncludeTotalCount=$pscmdlet.pagingparameters.includetotalcount
    }

    if ($ScopeNames -ne $null) {
        $requestArguments['ScopeNames'] = $ScopeNames
    }

    if ( $Connection -ne $null ) {
        $requestArguments['Connection'] = $Connection
    }

    if ( $resolvedUri.Class -ne '__Root' ) {
        Invoke-GraphRequest @requestArguments | foreach {
            $result = $_ | Get-GraphUri
            $results += $result
        }
    }

    if ( ! $resolvedUri.Collection ) {
        Get-GraphUri $ItemRelativeUri[0] -children | foreach {
            $results += $_
        }
    }

    $results
}
