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

        [switch] $IncludeAll,

        [switch] $DetailedChildren,

        [HashTable] $Headers = $null,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    if ( $Version -or $Connection -or ($Cloud -ne ([GraphCloud]::Public)) ) {
        throw [NotImplementedException]::new("Non-default context not yet implemented")
    }

    $resolvedUri = if ( $ItemRelativeUri[0] -ne '.' ) {
        Get-GraphUri $ItemRelativeUri[0]
    } else {
        $context = $::.GraphContext |=> GetCurrent
        $parser = new-so SegmentParser $context
        $::.SegmentHelper |=> ToPublicSegment $parser $context.location
    }

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

    $graphException = $false

    if ( $::.SegmentHelper.IsValidLocationClass($resolvedUri.Class) ) {
        try {
            Invoke-GraphRequest @requestArguments | foreach {
                $result = if ( (! $resolvedUri.Collection) -or $DetailedChildren.IsPresent ) {
                    $_ | Get-GraphUri
                } else {
                    $::.SegmentHelper.ToPublicSegmentFromGraphItem($resolvedUri, $_)
                }

                $results += $result
            }
        } catch [System.Net.WebException] {
            $graphException = $true
            $statusCode = $_.exception.response.statuscode
            $_.exception | write-verbose
            if ( $statusCode -eq 'Unauthorized' ) {
                write-verbose "Graph endpoint returned 'Unauthorized' - ignoring failure"
                write-warning "Graph endpoint returned 'Unauthorized', retry after re-authenticating via the 'Connect-Graph' cmdlet and requesting appropriate additional application scopes"
            } elseif ( $statusCode -eq 'Forbidden' ) {
                write-verbose "Graph endpoint returned 'Forbiddden' - ignoring failure"
            } elseif ( $statusCode -eq 'BadRequest' ) {
                write-verbose "Graph endpoint returned 'Bad request' - metadata may be inaccurate, ignoring failure"
            } else {
                throw $_.exception
            }
        }
    }

    if ( $graphException -or ! $resolvedUri.Collection ) {
        Get-GraphUri $ItemRelativeUri[0] -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
            $results += $_
        }
    }

    $results
}
