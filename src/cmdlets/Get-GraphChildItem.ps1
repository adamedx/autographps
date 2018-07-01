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

. (import-script Invoke-GraphRequest)
. (import-script Get-GraphUri)
. (import-script common/PreferenceHelper)
. (import-script common/ItemResultHelper)

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true)]
    param(
        [parameter(position=0)]
        [Uri[]] $ItemRelativeUri = @('.'),

        [parameter(position=1)]
        [String] $Query = $null,

        [String] $ODataFilter = $null,

        [String[]] $Select = $null,

        [String[]] $Expand = $null,

        [parameter(parametersetname='MSGraphNewConnection')]
        [String[]] $ScopeNames = $null,

        [Object] $ContentColumns = $null,

        [String] $Version = $null,

        [switch] $RawContent,

        [switch] $AbsoluteUri,

        [switch] $IncludeAll,

        [switch] $DetailedChildren,

        [switch] $DataOnly,

        [Switch] $RequireMetadata,

        [HashTable] $Headers = $null,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null,

        [string] $ResultVariable = $null
    )

    if ( $Version -or $Connection -or ($Cloud -ne ([GraphCloud]::Public)) ) {
        throw [NotImplementedException]::new("Non-default context not yet implemented")
    }

    $context = $null

    $mustWaitForMissingMetadata = $RequireMetadata.IsPresent -or (__Preference__MustWaitForMetadata)

    $resolvedUri = if ( $ItemRelativeUri[0] -ne '.' ) {
        $metadataArgument = @{IgnoreMissingMetadata=(new-object System.Management.Automation.SwitchParameter (! $mustWaitForMissingMetadata))}
        Get-GraphUri $ItemRelativeUri[0] @metadataArgument
    } else {
        $context = $::.GraphContext |=> GetCurrent
        $parser = new-so SegmentParser $context $null $true

        $contextReady = ($::.GraphContext |=> GetMetadataStatus $context) -eq [MetadataStatus]::Ready

        if ( ! $contextReady -and ! $mustWaitForMissingMetadata ) {
            $::.SegmentHelper |=> ToPublicSegment $parser $::.GraphSegment.NullSegment
        } else {
            $::.SegmentHelper |=> ToPublicSegment $parser $context.location
        }
    }

    if ( ! $context ) {
        $components = $resolvedUri.Path -split ':'

        if ( $components.length -gt 2) {
            throw "'$($resolvedUri.Path)' is not a valid graph location uri"
        }

        $context = $::.logicalgraphmanager.Get().contexts[$components[0]].context
    }

    $results = @()

    $requestArguments = @{
        RelativeUri=$ItemRelativeUri[0]
        Query = $Query
        ODataFilter = $ODataFilter
        Select = $Select
        Expand = $Expand
        Version=$Version
        RawContent=$RawContent
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

    $ignoreMetadata = ! $mustWaitForMissingMetadata -and ($resolvedUri.Class -eq 'Null')

    if ( $resolvedUri.Class -ne '__Root' -and ($::.SegmentHelper.IsValidLocationClass($resolvedUri.Class) -or $ignoreMetadata)) {
        try {
            Invoke-GraphRequest @requestArguments | foreach {
                $result = if ( ! $ignoreMetadata -and (! $RawContent.ispresent -and (! $resolvedUri.Collection -or $DetailedChildren.IsPresent) ) ) {
                    $_ | Get-GraphUri
                } else {
                    $::.SegmentHelper.ToPublicSegmentFromGraphItem($resolvedUri, $_)
                }

                $translatedResult = if ( ! $RawContent.IsPresent -and $ContentColumns ) {
                    $ContentColumns | foreach {
                        $specificOutputColumn = $false
                        $outputColumnName = $_
                        $contentColumnName = if ( $_ -is [String] ) {
                            $_
                        } elseif ( $_ -is [HashTable] ) {
                            if ( $_.count -ne 1 ) {
                                throw "Argument '$($_)' must have exactly one key, specify '@{source1=dest1}, @{source2=dest2}' instead"
                            }
                            $specificOutputColumn = $true
                            $outputColumnName = $_.values[0]
                            $_.keys[0]
                        } else {
                            throw "Invalid Content column '$($_.tostring())' of type '$($_.gettype())' specified -- only types [String] and [HashTable] are permitted"
                        }

                        $propertyName = if ( $specificOutputColumn ) {
                            $outputColumnName
                        } else {
                            if ( $result | gm $outputColumnName -erroraction silentlycontinue ) {
                                "_$outputColumnName"
                            } else {
                                $outputColumnName
                            }
                        }

                        $result | add-member -membertype noteproperty -name $propertyName -value ($result.content | select -erroraction silentlycontinue -expandproperty $contentColumnName)
                    }
                }

                $results += $result
            }
        } catch [System.Net.WebException] {
            $graphException = $true
            $statusCode = if ( $_.exception.response | gm statuscode -erroraction silentlycontinue ) {
                $_.exception.response.statuscode
            }
            $_.exception | write-verbose
            if ( $statusCode -eq 'Unauthorized' -or $statusCode -eq 'Forbidden' ) {
                write-warning "Graph endpoint returned 'Unauthorized' accessing '$($requestArguments.RelativeUri)'. Retry after re-authenticating via the 'Connect-Graph' cmdlet and requesting appropriate application scopes. See this location for documentation on scopes that may apply to this part of the Graph: 'https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference'."
                $lastError = get-grapherror
                if ($lastError -and ($lastError | gm ResponseStream -erroraction silentlycontinue)) {
                    $lastError.ResponseStream | write-warning
                }
            } elseif ( $statusCode -eq 'BadRequest' ) {
                write-verbose "Graph endpoint returned 'Bad request' - ignoring failure"
            } else {
                throw
            }
        }
    }

    if ( $ignoreMetadata ) {
        write-warning "Metadata for Graph is not ready and 'RequireMetadata' was not specified, only returning responses from Graph"
    }

    if ( ! $ignoreMetadata -and ! $DataOnly.IsPresent -and ($graphException -or ! $resolvedUri.Collection) ) {
        Get-GraphUri $ItemRelativeUri[0] -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
            $results += $_
        }
    }

    $targetResultVariable = __GetResultVariable $ResultVariable
    $targetResultVariable.value = $results
    $results
}
