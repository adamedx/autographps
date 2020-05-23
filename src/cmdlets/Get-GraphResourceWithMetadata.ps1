# Copyright 2019, Adam Edwards
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
. (import-script Get-GraphUriInfo)
. (import-script ../common/GraphAccessDeniedException)
. (import-script common/TypeUriParameterCompleter)

function Get-GraphResourceWithMetadata {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true, defaultparametersetname='byuri')]
    param(
        [parameter(position=0, parametersetname='byuri', valuefrompipeline=$true)]
        [Uri] $Uri = $null,

        [parameter(position=1)]
        [Alias('Property')]
        [String[]] $Select = $null,

        [parameter(position=2)]
        [String] $SimpleMatch = $null,

        [String] $Filter = $null,

        [HashTable] $PropertyFilter = $null,

        [parameter(parametersetname='GraphItem', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem,

        [parameter(parametersetname='GraphUri', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Uri] $GraphUri,

        [String] $Query = $null,

        [String] $Search = $null,

        [String[]] $Expand = $null,

        [Alias('Sort')]
        [object[]] $OrderBy = $null,

        [Switch] $Descending,

        [switch] $RawContent,

        [switch] $AbsoluteUri,

        [switch] $IncludeAll,

        [switch] $Recurse,

        [switch] $ChildrenOnly,

        [switch] $DetailedChildren,

        [switch] $ContentOnly,

        [switch] $DataOnly,

        [Switch] $NoRequireMetadata,

        [Switch] $StrictOutput,

        [Switch] $IgnoreUnauthorized,

        [HashTable] $Headers = $null,

        [Guid] $ClientRequestId,

        [string] $ResultVariable = $null,

        [string] $GraphName
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $filters = if ( $SimpleMatch ) { 1 } else { 0 }
        $filters += if ( $Filter ) { 1 } else { 0 }
        $filters += if ( $PropertyFilter ) { 1 } else { 0 }

        if ( $filters -gt 1 ) {
            throw "Only one of SimpleMatch, Filter, or PropertyFilter parameters may be specified -- specify no more than one of these paramters and retry the command."
        }

        $targetFilter = $::.QueryTranslationHelper |=> ToFilterParameter $PropertyFilter $Filter

        $context = $null

        $mustWaitForMissingMetadata = (__Preference__MustWaitForMetadata) -and ! $NoRequireMetadata.IsPresent
        $responseContentOnly = $RawContent.IsPresent -or $ContentOnly.IsPresent

        $results = @()
        $intermediateResults = @()
        $contexts = @()
    }

    process {
        $assumeRoot = $false

        $specifiedUri = if ( $uri ) {
            $Uri
        } else {
            $GraphUri
        }

        $resolvedUri = if ( $specifiedUri -and $specifiedUri -ne '.' -or $GraphItem ) {
            $GraphArgument = @{}

            if ( $GraphName ) {
                $graphContext = $::.logicalgraphmanager.Get().contexts[$GraphName]
                if ( ! $graphContext ) {
                    throw "The specified graph '$GraphName' does not exist"
                }
                $context = $graphContext.context
                $GraphArgument['GraphScope'] = $GraphName
            }

            $targetUri = if ( $GraphItem ) {
                if ( ! ( $GraphItem | gm id -erroraction ignore ) ) {
                    throw "The GraphItem parameter does not contain the required id property for an item returned by the Graph API"
                }
                $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $null $GraphItem.id $GraphItem
                if ( ! $requestInfo.Uri ) {
                    throw "Unable to determine Uri for specified GraphItem parameter -- specify the TypeName or Uri parameter and retry the command"
                }
                $requestInfo.Uri
            } else {
                $specifiedUri
            }

            $metadataArgument = @{IgnoreMissingMetadata=(new-object System.Management.Automation.SwitchParameter (! $mustWaitForMissingMetadata))}

            Get-GraphUriInfo $targetUri @metadataArgument @GraphArgument -erroraction stop
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
            $parsedPath = $::.GraphUtilities |=> ParseLocationUriPath $resolvedUri.Path
            $context = if ( $parsedPath.ContextName ) {
                $graphContext = $::.logicalgraphmanager.Get().contexts[$parsedPath.ContextName]
                if ( $graphContext ) {
                    $graphContext.context
                }
            }
            if ( ! $context ) {
                throw "'$($resolvedUri.Path)' is not a valid graph location uri"
            }
        }

        # The filter for SimpleMatch can only be determined when the type, and thus the
        # context, is known, so it is request specific and must be computed here.
        if ( $SimpleMatch ) {
            $targetFilter = $::.QueryTranslationHelper |=> GetSimpleMatchFilter $context $resolvedUri.FullTypeName $SimpleMatch
        }

        $requestArguments = @{
            # Handle the case of resolvedUri being incomplete because of missing data -- just
            # try to use the original URI
            Uri = if ( $resolvedUri.Type -ne 'null' ) { $resolvedUri.GraphUri } else { $specifiedUri }
            Query = $Query
            Filter = $targetFilter
            Search = $Search
            Select = $Select
            Expand = $Expand
            OrderBy = $OrderBy
            Descending = $Descending
            RawContent=$RawContent
            AbsoluteUri=$AbsoluteUri
            Headers=$Headers
            First=$pscmdlet.pagingparameters.first
            Skip=$pscmdlet.pagingparameters.skip
            IncludeTotalCount=$pscmdlet.pagingparameters.includetotalcount
            Connection = $context.connection
            # Due to a defect in ScriptClass where verbose output of ScriptClass work only shows
            # for the current module and not the module we are calling into, we explicitly set
            # verbose for a command from outside this module
            Verbose=([System.Management.Automation.SwitchParameter]::new($VerbosePreference -eq 'Continue'))
        }

        if ( $ClientRequestId ) {
            $requestArguments['ClientRequestId'] = $ClientRequestId
        }

        $graphException = $false

        $ignoreMetadata = ! $mustWaitForMissingMetadata -and ( ($resolvedUri.Class -eq 'Null') -or $assumeRoot )

        $noUri = ! $GraphItem -and ( ! $specifiedUri -or $specifiedUri -eq '.' )

        $emitTarget = $null
        $emitChildren = $null
        $emitRoot = $true

        if ( $StrictOutput.IsPresent ) {
            $emitTarget = $::.SegmentHelper.IsValidLocationClass($resolvedUri.Class) -or $ignoreMetadata
            $emitChildren = ! $resolvedUri.Collection -or $Recurse.IsPresent
        } else {
            $emitTarget = ( ( ! $noUri -or $ignoreMetadata ) -and ! $ChildrenOnly.IsPresent ) -or $resolvedUri.Collection
            $emitRoot = ! $noUri -or $ignoreMetadata
            $emitChildren = ( $noUri -or ! $emitTarget -or $Recurse.IsPresent ) -or $ChildrenOnly.IsPresent
        }

        write-verbose "Uri unspecified: $noUri, Emit Root: $emitRoot, Emit target: $emitTarget, EmitChildren: $emitChildren"

        if ( $resolvedUri.Class -eq '__Root' ) {
            if ( $emitRoot ) {
                $results += $resolvedUri
            }
        } elseif ( $emitTarget ) {
            try {
                $graphResult = Invoke-GraphRequest @requestArguments
                $intermediateResults += $graphResult
                # We need the context with each result, because in theory each result came from a different
                # Graph since we allow arbitrary URI's to be supplied to the pipeline
                $graphResult | foreach {
                    $contexts += $context
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
                if ($lastError -and ($lastError | get-member ResponseStream -erroraction ignore)) {
                    $lastError.ResponseStream | write-warning
                }
            }
        }

        if ( $ignoreMetadata ) {
            write-warning "Metadata processing for Graph is in progress -- responses from Graph will be returned but no metadata will be added. You can retry this cmdlet later or retry it now with the '-NoRequireMetadata' option unspecified or set to `$false to force a wait until processing is complete in order to obtain the complete response."
        }

        if ( ! $DataOnly.ispresent ) {
            if ( ! $ignoreMetadata -and ( $graphException -or $emitChildren ) ) {
                Get-GraphUriInfo $resolvedUri.GraphUri -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
                    $results += $_
                }
            }
        }
    }

    end {
        $contextIndex = 0

        foreach ( $intermediateResult in $intermediateResults ) {
            $currentContext = $contexts[$contextIndex] # The context associated with this result
            $contextIndex++
            if ( 'GraphSegmentDisplayType' -in $intermediateResult.pstypenames ) {
                $results += $intermediateResult
                continue
            }

            $restResult = $intermediateResult

            $result = if ( ! $ignoreMetadata -and (! $RawContent.ispresent -and (! $resolvedUri.Collection -or $DetailedChildren.IsPresent) ) ) {
                if ( ! $responseContentOnly ) {
                    $restResult | Get-GraphUriInfo -GraphScope $context.name
                } else {
                    $restResult
                }
            } else {
                if ( ! $responseContentOnly ) {
                    $::.SegmentHelper.ToPublicSegmentFromGraphItem($currentContext, $restResult)
                } else {
                    $restResult
                }
            }

            $noResults = $false

            # TODO: Investigate scenarios where empty collection results sometimes return
            # a non-empty result containing and empty 'value' field in the content
            if ( $resolvedUri.Collection -and ! $RawContent.IsPresent ) {
                if ( $restResult -and ( $restResult | gm value -erroraction ignore ) -and ! $restResult.value ) {
                    $noResults = $true
                }
            }

            if ( ! $noResults ) {
                $results += $result
            }
        }

        __AutoConfigurePrompt $context

        $targetResultVariable = $::.ItemResultHelper |=> GetResultVariable $ResultVariable
        $targetResultVariable.value = $results

        if ( $results ) {
            $results
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Select (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Expand (new-so TypeUriParameterCompleter Property $false NavigationProperty)
