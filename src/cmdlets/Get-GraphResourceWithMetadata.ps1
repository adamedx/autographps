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
. (import-script Get-GraphUri)
. (import-script ../common/GraphAccessDeniedException)

function Get-GraphResourceWithMetadata {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true)]
    param(
        [parameter(position=0)]
        [Uri[]] $Uri = @('.'),

        [parameter(position=1)]
        [Alias('Property')]
        [String[]] $Select = $null,

        [parameter(position=2)]
        [String] $Filter = $null,

        [String] $Query = $null,

        [String] $Search = $null,

        [String[]] $Expand = $null,

        [Alias('Sort')]
        $OrderBy = $null,

        [Switch] $Descending,

        [switch] $RawContent,

        [switch] $AbsoluteUri,

        [switch] $IncludeAll,

        [switch] $Recurse,

        [switch] $ChildrenOnly,

        [switch] $DetailedChildren,

        [switch] $ContentOnly,

        [switch] $DataOnly,

        [Switch] $RequireMetadata,

        [Switch] $StrictOutput,

        [HashTable] $Headers = $null,

        [Guid] $ClientRequestId,

        [string] $ResultVariable = $null,

        [string] $GraphName
    )

    Enable-ScriptClassVerbosePreference

    $context = $null

    $mustWaitForMissingMetadata = $RequireMetadata.IsPresent -or (__Preference__MustWaitForMetadata)
    $assumeRoot = $false

    $resolvedUri = if ( $Uri[0] -ne '.' ) {
        $GraphArgument = @{}

        if ( $GraphName ) {
            $graphContext = $::.logicalgraphmanager.Get().contexts[$GraphName]
            if ( ! $graphContext ) {
                throw "The specified graph '$GraphName' does not exist"
            }
            $context = $graphContext.context
            $GraphArgument['GraphScope'] = $GraphName
        }

        $metadataArgument = @{IgnoreMissingMetadata=(new-object System.Management.Automation.SwitchParameter (! $mustWaitForMissingMetadata))}
        Get-GraphUri $Uri[0] @metadataArgument @GraphArgument -erroraction stop
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

    $results = @()

    $requestArguments = @{
        Uri = $Uri[0]
        Query = $Query
        Filter = $Filter
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

    $noUri = ! $Uri -or $Uri -eq '.'

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
            Invoke-GraphRequest @requestArguments | foreach {
                $result = if ( ! $ignoreMetadata -and (! $RawContent.ispresent -and (! $resolvedUri.Collection -or $DetailedChildren.IsPresent) ) ) {
                    if ( ! $ContentOnly.IsPresent ) {
                        $_ | Get-GraphUri
                    } else {
                        $_
                    }
                } else {
                    if ( ! $ContentOnly.IsPresent ) {
                        $::.SegmentHelper.ToPublicSegmentFromGraphItem($resolvedUri, $_)
                    } else {
                        $_
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
            if ($lastError -and ($lastError | get-member ResponseStream -erroraction ignore)) {
                $lastError.ResponseStream | write-warning
            }
        }
    }

    if ( $ignoreMetadata ) {
        write-warning "Metadata processing for Graph is in progress -- responses from Graph will be returned but no metadata will be added. You can retry this cmdlet later or retry it now with the '-RequireMetadata' option to force a wait until processing is complete in order to obtain the complete response."
    }

    if ( ! $DataOnly.ispresent ) {
        if ( ! $ignoreMetadata -and ( $graphException -or $emitChildren ) ) {
            Get-GraphUri $Uri[0] -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
                $results += $_
            }
        }
    }

    __AutoConfigurePrompt $context

    $targetResultVariable = $::.ItemResultHelper |=> GetResultVariable $ResultVariable
    $targetResultVariable.value = $results
    $results
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Select (new-so WriteOperationParameterCompleter Property)
