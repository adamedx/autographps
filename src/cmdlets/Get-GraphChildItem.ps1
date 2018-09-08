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

. (import-script ../metadata/GraphManager)
. (import-script Get-GraphUri)

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true)]
    param(
        [parameter(position=0)]
        [Uri[]] $ItemRelativeUri = @('.'),

        [parameter(position=1)]
        [String] $Query = $null,

        [String] $ODataFilter = $null,

        [String] $Search = $null,

        [String[]] $Select = $null,

        [String[]] $Expand = $null,

        [Alias('Sort')]
        $OrderBy = $null,

        [Switch] $Descending,

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
    $assumeRoot = $false

    $resolvedUri = if ( $ItemRelativeUri[0] -ne '.' ) {
        $metadataArgument = @{IgnoreMissingMetadata=(new-object System.Management.Automation.SwitchParameter (! $mustWaitForMissingMetadata))}
        Get-GraphUri $ItemRelativeUri[0] @metadataArgument
    } else {
        $context = $::.GraphContext |=> GetCurrent
        $parser = new-so SegmentParser $context $null $true

        $contextReady = ($::.GraphManager |=> GetMetadataStatus $context) -eq [MetadataStatus]::Ready

        if ( ! $contextReady -and ! $mustWaitForMissingMetadata ) {
            $assumeRoot = $true
            $::.SegmentHelper |=> ToPublicSegment $parser $::.GraphSegment.RootSegment
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
        Search = $Search
        Select = $Select
        Expand = $Expand
        OrderBy = $OrderBy
        Descending = $Descending
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

    $ignoreMetadata = ! $mustWaitForMissingMetadata -and ( ($resolvedUri.Class -eq 'Null') -or $assumeRoot )

    if ( $resolvedUri.Class -eq '__Root' ) {
        $results += $resolvedUri
    } elseif ( $::.SegmentHelper.IsValidLocationClass($resolvedUri.Class) -or $ignoreMetadata ) {
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
        } catch [GraphAccessDeniedException] {
            # In some cases, we want to allow the user to make a mistake that results in an error from Graph
            # but allows the cmdlet to continue to enumerate child segments known from local metadata. For
            # example, the application may not have the scopes to perform a GET on some URI which means Graph
            # has to return a 4xx, but its still valid to enumerate children since the question of what
            # segments may follow a given segment is not affected by scope. Without this accommodation,
            # exploration of the Graph with this cmdlet would be tricky as you'd need to have every possible
            # scope to avoid hitting blocking errors. It's quite possible that you *can't* get all the scopes
            # anyway (you may need admin approval), but you should still be able to see what's possible, especially
            # since that question is one this cmdlet can answer. :)
            $graphException = $true
            $_.exception | write-verbose
            write-warning $_.exception.message
            $lastError = get-grapherror
            if ($lastError -and ($lastError | gm ResponseStream -erroraction silentlycontinue)) {
                $lastError.ResponseStream | write-warning
            }
        }
    }

    if ( $ignoreMetadata ) {
        write-warning "Metadata processing for Graph is in progress -- responses from Graph will be returned but no metadata will be added. You can retry this cmdlet later or retry it now with the '-RequireMetadata' option to force a wait until processing is complete in order to obtain the complete response."
    }

    if ( ! $DataOnly.ispresent ) {
        if ( ! $ignoreMetadata -and ($graphException -or ! $resolvedUri.Collection) ) {
            Get-GraphUri $ItemRelativeUri[0] -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
                $results += $_
            }
        }
        __AutoConfigurePrompt $context
    }

    $targetResultVariable = __GetResultVariable $ResultVariable
    $targetResultVariable.value = $results
    $results
}

$::.ArgumentCompletionHelper |=> RegisterArgumentCompleter Get-GraphChildItem ItemRelativeUri ([GraphUriCompletionType]::LocationOrMethodUri )
