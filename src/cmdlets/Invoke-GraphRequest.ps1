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

. (import-script New-GraphConnection)
. (import-script ../common/GraphUtilities)
. (import-script common/QueryHelper)
. (import-script ../REST/GraphRequest)
. (import-script ../REST/GraphErrorRecorder)

function Invoke-GraphRequest {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true)]
    param(
        [parameter(position=0, mandatory=$true)]
        [Uri[]] $RelativeUri,

        [parameter(position=1)]
        [String] $Verb = 'GET',

        [parameter(position=2)]
        $Payload = $null,

        [String] $Query = $null,

        [String] $ODataFilter = $null,

        [String[]] $Select = $null,

        [String[]] $Expand = $null,

        [Alias('Sort')]
        $OrderBy = $null,

        [Switch] $Descending,

        [parameter(parametersetname='MSGraphNewConnection')]
        [String[]] $ScopeNames = $null,

        [String] $Version = $null,

        [switch] $RawContent,

        [switch] $AbsoluteUri,

        [HashTable] $Headers = $null,

        [parameter(parametersetname='AADGraphNewConnection', mandatory=$true)]
        [switch] $AADGraph,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    $::.GraphErrorRecorder |=> StartRecording

    if ( $Query ) {
        if ( $ODataFilter -or $Select -or $OrderBy ) {
            throw [ArgumentException]::new("'ODataFilter' and 'Select' options may not specified with 'Query'")
        }
    }

    if ( $Descending.IsPresent -and ! $OrderBy ) {
        throw [ArgumentException]::new("'Descending' option was specified without 'OrderBy'")
    }

    $orderQuery = if ( $OrderBy ) {
        try {
            $::.QueryHelper |=> GetOrderQueryFromOrderByParameters $OrderBy $Descending.IsPresent
        } catch {
            throw
        }
    }

    if ( $AbsoluteUri.IsPresent ) {
        if ( $RelativeUri.length -gt 1 ) {
            throw "More than one Uri was specified when AbsoluteUri was specified -- only one Uri is allowed when AbsoluteUri is configured"
        }
    } elseif ( $RelativeUri[0].IsAbsoluteUri ) {
        throw "An absolute URI was specified -- specify a URI relative to the graph host and version, or specify -AbsoluteUri"
    }

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

    $requestQuery = if ( $Query ) {
        @($Query)
    } else {
        $queryParameters = [string[]] @()

        if ( $Select ) {
            $queryParameters += @('$select={0}') -f ($Select -join ',')
        }

        if ( $Expand ) {
            $queryParameters += @('$expand={0}') -f ($Expand -join ',')
        }

        if ( $ODataFilter ) {
            $queryParameters += @('$filter={0}' -f $ODataFilter)
        }

        if ( $orderQuery ) {
            $queryParameters += @('$orderBy={0}' -f $orderQuery)
        }

        if ( $queryParameters.length -gt 0 ) {
            $queryParameters
        }
    }

    if ( $pscmdlet.pagingparameters.includetotalcount.ispresent -eq $true ) {
        write-verbose 'Including the total count of results'
        $requestQuery += '$count'
    }

    # Cast it in case this is a deserialized object --
    # workaround for a defect in ScriptClass
    switch ([GraphType] $graphType) {
        ([GraphType]::AADGraph) { $defaultVersion = '1.6' }
        ([GraphType]::MSGraph) { $defaultVersion = 'GraphContext' |::> GetDefaultVersion }
        default {
            throw "Unexpected identity type '$graphType'"
        }
    }

    $currentContext = $null

    $graphConnection = if ( $Connection -eq $null ) {
        if ( $graphType -eq ([GraphType]::AADGraph) ) {
            $::.GraphConnection |=> NewSimpleConnection ([GraphType]::AADGraph) $cloud $MSGraphScopeNames
        } else {
            $currentContext = 'GraphContext' |::> GetConnection $null $null $cloud $ScopeNames
            $currentContext.Connection
        }
    } else {
        $Connection
    }

    $uriInfo = if ( $AbsoluteUri.ispresent ) {
        write-verbose "Caller specified AbsoluteUri -- interpreting uri as absolute"
        $specificContext = new-so GraphContext $connection $version 'local'
        $info = $::.GraphUtilities |=> ParseGraphUri $RelativeUri[0] $connection
        write-verbose "Absolute uri parsed as relative '$($info.GraphRelativeUri)' and version $($info.GraphVersion)"
        if ( ! $info.IsAbsolute ) {
            throw "Absolute Uri was specified, but given Uri was not absolute: '$($RelativeUri[0])'"
        }
        if ( ! $info.IsContextCompatible ) {
            throw "The version '$version' and connection endpoint '$($Connection.GraphEndpoint.Graph)' is not compatible with the uri '$RelativeUri'"
        }
        $info
    }

    $apiVersion = if ( $uriInfo -and $uriInfo.GraphVersion ) {
        $uriInfo.GraphVersion
    } elseif ( $Version -eq $null -or $version.length -eq 0 ) {
        if ( $currentContext ) {
            write-verbose "Using context Graph version '$($currentContext.Version)'"
            $currentContext.Version
        } else {
            write-verbose "Using default Graph version '$defaultVersion'"
            $defaultVersion
        }
    } else {
        $Version
    }

    $tenantQualifiedVersionSegment = if ( $graphType -eq ([GraphType]::AADGraph ) ) {
        $graphConnection |=> Connect
        $graphConnection.Identity.Token.TenantId
    } else {
        $apiVersion
    }

    $firstIndex = if ( $pscmdlet.pagingparameters.Skip -ne $null -and $pscmdlet.pagingparameters.skip -ne 0 ) {
        write-verbose "Skipping the first '$($pscmdlet.pagingparameters.skip)' parameters"
        $pscmdlet.pagingparameters.Skip
    }

    $maxReturnedResults = $null
    $maxResultCount = if ( $pscmdlet.pagingparameters.first -ne $null -and $pscmdlet.pagingparameters.first -lt [Uint64]::MaxValue ) {
        $pscmdlet.pagingparameters.First | tee -variable maxReturnedResults
    } else {
        10
    }

    $skipCount = $firstIndex
    $results = @()

    $inputUriRelative = if ( ! $uriInfo ) {
        $RelativeUri[0]
    } else {
        $uriInfo.GraphRelativeUri
    }

    $contextUri = $::.GraphUtilities |=> ToGraphRelativeUri $inputUriRelative
    $graphRelativeUri = $::.GraphUtilities |=> JoinRelativeUri $tenantQualifiedVersionSegment $contextUri

    $countError = $false
    $optionalCountResult = $null

    while ( $graphRelativeUri -ne $null -and ($graphRelativeUri.tostring().length -gt 0) -and ($maxResultCount -eq $null -or $results.length -lt $maxResultCount) ) {
        if ( $graphType -eq ([GraphType]::AADGraph) ) {
            $graphRelativeUri = $graphRelativeUri, "api-version=$apiVersion" -join '?'
        }

        $graphResponse = if ( $graphConnection.status -ne ([GraphConnectionStatus]::Offline) ) {
            $request = new-so GraphRequest $graphConnection $graphRelativeUri $Verb $Headers $requestQuery
            $request |=> SetBody $Payload
            $request |=> Invoke $skipCount
        }

        $skipCount = $null

        $content = if ( $graphResponse -and $graphResponse.Entities -ne $null ) {
            $graphRelativeUri = $graphResponse.Nextlink
            if (! $RawContent.ispresent) {
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
                $graphResponse |=> Content
            }
        } else {
            $graphRelativeUri = $null
            if ( $graphResponse ) {
                $graphResponse |=> Content
            }
        }

        if ( $graphResponse -and ( ! $RawContent.ispresent ) ) {
            # Add __ItemContext to decorate the object with its source uri.
            # Do this as a script method to prevent deserialization
            $requestUriNoQuery = $request.Uri.GetLeftPart([System.UriPartial]::Path)
            $ItemContextScript = [ScriptBlock]::Create("[PSCustomObject] @{RequestUri=`"$requestUriNoQuery`"}")
            $content | foreach {
                $_ | add-member -membertype scriptmethod -name __ItemContext -value $ItemContextScript
            }
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

    if ( $maxReturnedResults ) {
        $results | select -first $maxReturnedResults
    } else {
        $results
    }
}
