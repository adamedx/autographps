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
. (import-script New-GraphConnection)
. (import-script GraphResponse)

function Invoke-GraphRequest {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true)]
    param(
        [parameter(position=0, mandatory=$true)]
        [Uri[]] $RelativeUri,

        [parameter(position=1)]
        [String] $Verb = 'GET',

        [parameter(position=2, parametersetname='MSGraphNewConnection')]
        [String[]] $ScopeNames = $null,

        [parameter(position=3)]
        $Payload = $null,

        [String] $Version = $null,

        [switch] $JSON,

        [parameter(parametersetname='AADGraphNewConnection', mandatory=$true)]
        [switch] $AADGraph,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    $defaultVersion = $null
    $graphType = if ($Connection -ne $null ) {
        $Connection.GraphEndpoint.Type
    } elseif ( $AADGraph.ispresent ) {
        ([GraphType]::AADGraph)
    } else {
        ([GraphType]::MSGraph)
    }

    $MSGraphScopeNames = if ( $ScopeNames -ne $null ) {
        if ( $Connection -ne $null ) {
            throw "Scopes may not be specified via -ScopeNames if an existing connection is supplied with -Connection"
        }
        $ScopeNames
    } else {
        @('User.Read')
    }

    switch ($graphType) {
        ([GraphType]::AADGraph) { $defaultVersion = '1.6' }
        ([GraphType]::MSGraph) { $defaultVersion = 'v1.0' }
        default {
            throw "Unexpected identity type '$graphType'"
        }
    }

    if ( $verb -ne 'GET' ) {
        if ( ($pscmdlet.pagingparameters.Skip.ispresent) -or
             ($pscmdlet.pagingparameters.First.ispresent) -or
             ($pscmdlet.pagingparameters.IncludeTotalCount.ispresent) )
        {
            throw "A paging argument of 'Skip', 'First', or 'IncludeTotalCount' may not be specified for the '$verb' verb"
        }
    }

    $apiVersion = if ( $Version -eq $null -or $version.length -eq 0 ) {
        $defaultVersion
    } else {
        $Version
    }

    $graphConnection = if ( $Connection -eq $null ) {
        $connectionArguments = if ( $AADGraph.ispresent ) {
            @{AADGraph = $AADGraph}
        } else {
            @{Cloud=$Cloud;ScopeNames=$MSGraphScopeNames}
        }
        New-GraphConnection @connectionArguments
    } else {
        $Connection
    }

    $tenantQualifiedVersionSegment = if ( $graphType -eq ([GraphType]::AADGraph) ) {
        $graphConnection |=> Connect
        $graphConnection.Identity.Token.TenantId
    } else {
        $apiVersion
    }

    $firstIndex = if ( $pscmdlet.pagingparameters.Skip -ne $null -and $pscmdlet.pagingparameters.skip -ne 0 ) {
        write-verbose "Skipping the first '$($pscmdlet.pagingparameters.skip)' parameters"
        $pscmdlet.pagingparameters.Skip
    }

    $maxResultCount = if ( $pscmdlet.pagingparameters.first -ne $null -and $pscmdlet.pagingparameters.first -lt [Uint64]::MaxValue ) {
        $pscmdlet.pagingparameters.First
    }

    $skipCount = $firstIndex
    $results = @()
    $graphRelativeUri = $tenantQualifiedVersionSegment, $RelativeUri[0] -join '/'

    $query = $null
    $countError = $false
    $optionalCountResult = $null
    if ( $pscmdlet.pagingparameters.includetotalcount.ispresent -eq $true ) {
        write-verbose 'Including the total count of results'
        $query = '$count'
    }

    while ( $graphRelativeUri -ne $null -and ($maxResultCount -eq $null -or $results.length -lt $maxResultCount) ) {
        if ( $graphType -eq ([GraphType]::AADGraph) ) {
            $graphRelativeUri = $graphRelativeUri, "api-version=$apiVersion" -join '?'
        }

        $request = new-so GraphRequest $graphConnection $graphRelativeUri $Verb $null $null
        $response = $request |=> Invoke $skipCount
        $skipCount = $null
        $deserializedContent = $response |=> GetDeserializedContent

        $content = if ( $response |=> HasJsonContent ) {
            $graphResponse = new-so GraphResponse $deserializedContent
            $graphRelativeUri = $graphResponse.Nextlink
            if (! $JSON.ispresent) {
                $entities = if ( $graphResponse.entities -is [Object[]] -and $graphResponse.entities.length -eq 1 ) {
                    @([PSCustomObject] $graphResponse.entities)
                } elseif ($graphResponse.entities -is [HashTable]) {
                    @([PSCustomObject] $graphResponse.Entities)
                } else {
                    $graphResponse.Entities
                }

                if ( $pscmdlet.pagingparameters.includetotalcount.ispresent -eq $true -and $results.length -eq 0 ) {
                    try {
                        $optionalCountResult = $graphResponse.RestResponse.value.count
                    } catch {
                        $countError = $true
                    }
                }
                $entities
            } else {
                $response.content
            }
        } else {
            $graphRelativeUri = $null
            $deserializedContent
        }

        $results += $content
    }

    if ($pscmdlet.pagingparameters.includetotalcount.ispresent -eq $true) {
        $accuracy = [double] 1.0
        $count = if ( $optionalCountResult -eq $null ) {
            $accuracy = [double] .1
            $results.length
        } else {
            if ( $countError ) {
                $accuracy = [double] .5
            }
            $optionalCountResult
        }

        $PSCmdlet.PagingParameters.NewTotalCount($count,  $accuracy)
    }

    $results
}
