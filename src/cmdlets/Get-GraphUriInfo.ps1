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
. (import-script common/SegmentHelper)
. (import-script common/GraphUriParameterCompleter)

function Get-GraphUriInfo {
    [cmdletbinding()]
    param(
        [parameter(parametersetname='FromUriParents', position=0, mandatory=$true)]
        [parameter(parametersetname='FromUriChildren', position=0, mandatory=$true)]
        [parameter(parametersetname='FromUri', position=0, mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='FromUriChildren', mandatory=$true)]
        [parameter(parametersetname='FromObjectChildren', mandatory=$true)]
        [Switch] $Children,

        [parameter(parametersetname='FromUriChildren')]
        [parameter(parametersetname='FromObjectChildren')]
        [Switch] $LocatableChildren,

        [parameter(parametersetname='FromUriChildren')]
        [parameter(parametersetname='FromObjectChildren')]
        [uint16] $RecursionDepth = 1,

        [parameter(parametersetname='FromUriChildren')]
        [parameter(parametersetname='FromObjectChildren')]
        [Switch] $IncludeVirtualChildren,

        [parameter(parametersetname='FromUriParents', mandatory=$true)]
        [parameter(parametersetname='FromObjectParents', mandatory=$true)]
        [Switch] $Parents,

        [parameter(parametersetname='FromUriChildren')]
        [parameter(parametersetname='FromObjectChildren')]
        [Switch] $NoCycles,

        [Switch] $IgnoreMissingMetadata,

        [String] $GraphName = $null,

        [parameter(parametersetname='FromObjectParents', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='FromObjectChildren', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='FromObject', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem
    )

    Enable-ScriptClassVerbosePreference

    $inputs = if ( $graphItem ) {
        $graphItem
    } else {
        $Uri
    }

    $results = @()

    $nextUris = new-object System.Collections.Generic.Queue[object[]]
    $inputs | foreach { $nextUris.Enqueue(@(0, $_)) }

    $DisallowedLocationClasses = if ( ! $IncludeVirtualChildren.IsPresent ) {
        @('EntityType')
    } else {
        @()
    }

    $validLocationClasses = if ( $LocatableChildren.ispresent ) {
        $allLocationClasses = $::.SegmentHelper.GetValidLocationClasses()
        $allLocationClasses | where { $_ -notin $DisallowedLocationClasses }
    } else {
        $null
    }

    $disallowVirtualChildren = $Children.ispresent -and ! $IncludeVirtualChildren.ispresent

    $context = if ( $GraphName ) {
        $::.Logicalgraphmanager.Get().contexts[$GraphName].Context
    }

    while ( $nextUris.Count -gt 0 ) {
        $currentItem = $nextUris.Dequeue()
        $currentDepth = $currentItem[0] + 1
        $currentUri = $currentItem[1]

        $graphCurrentItem = if ( $GraphItem ) {
            $currentUri
        }

        $uriSource = $currentUri

        $responseObject = $graphItem

        $inputUri = if ( $graphCurrentItem ) {
            if ( $graphCurrentItem | gm -membertype ScriptMethod __ItemMetadata -erroraction ignore ) {
                $metadata = $graphCurrentItem.__ItemMetadata()
                $context = $::.LogicalGraphManager.Get().GetContext($metadata.GraphName)
                $metadata.GraphUri
                $responseObject = $null
            } else {
                $uriFromResponse = $::.GraphUtilities.GetAbstractUriFromResponseObject($graphCurrentItem, $true, $null)

                if ( ! $uriFromResponse ) {
                    throw 'The specified object was not a valid Graph response object'
                }

                # Allow the caller to supply a context
                if ( ! $context ) {
                    $context = 'GraphContext' |::> GetCurrent
                }
                $uriFromResponse
            }
        } else {
            # TODO: Remove usage of ParseGraphRelativeLocation or update it -- turns out that if you
            # provide an absolute URI, it has non-deterministic behavior. :( Also, even for relative URIs
            # it assumes the default context which means you end up with this as the context even
            # though it wasn't specified in the URI. This is harmless unless the GraphName was specified
            # to this command, in which case it gets ignored.
            $parsedLocation = $::.GraphUtilities |=> ParseGraphRelativeLocation $currentUri
            if ( $parsedLocation.Context -and ! $GraphName) {
                # TODO: remove check for GraphName -- we are allowing specification of a URI with
                # a graph name in it to be overridden -- this is the lesser of two bad choices. We
                # can remove this capability once ParseGraphRelativeLocation is fixed.
                $context = $parsedLocation.Context
            }
            $parsedLocation.GraphRelativeUri
        }

        $parser = new-so SegmentParser $context $null ( $graphItem -ne $null )

        write-verbose "Uri '$uriSource' translated to '$inputUri'"

        $mustIgnoreMissingMetadata = $IgnoreMissingMetadata.IsPresent -or ! (__Preference__MustWaitForMetadata)

        $contextReady = ($::.GraphManager |=> GetMetadataStatus $context) -eq [MetadataStatus]::Ready

        if ( $mustIgnoreMissingMetadata -and ! $contextReady ) {
            if ( ! $Children.IsPresent ) {
                return $::.SegmentHelper |=> ToPublicSegment $parser $::.GraphSegment.NullSegment
            }
            return @()
        }

        $segments = $::.SegmentHelper |=> UriToSegments $parser $inputUri $responseObject

        $lastSegment = $segments | select -last 1

        $segmentTable = $null
        if ( $NoCycles.IsPresent ) {
            $segmentTable = @{}
            $segments | foreach { $segmentTable.Add($_.graphElement, $_) }
        }

        $instanceId = if ( $graphCurrentItem ) {
            $typeData = ($lastSegment.graphElement |=> GetEntity).typedata
            if ( $typeData.IsCollection ) {
                if ( $graphcurrentItem | gm -membertype noteproperty id -erroraction ignore) {
                    $graphcurrentItem.id
                } else {
                    $null
                }
            }
        }

        $lastPublicSegment = $::.SegmentHelper |=> ToPublicSegment $parser $lastSegment

        $count = if ( $Parents.ispresent ) {
            if ( $segments -is [Object[]] ) { $segments.length } else { 1 }
        } else {
            if ( $instanceId -or $Children.ispresent ) { 0 } else { 1 }
        }

        $segments | select -last $count | foreach {
            $results += ($::.SegmentHelper |=> ToPublicSegment $parser $_)
        }

        $childSegments = $null

        if ( $instanceId ) {
            $idSegment = $lastSegment |=> NewNextSegments ($::.GraphManager |=> GetGraph $context) $instanceId $validLocationClasses

            $additionalSegments = if ( $Children.IsPresent ) {
                $childSegments = $parser |=> GetChildren $idSegment $validLocationClasses | sort-object Name
            } else {
                # Create a new public segment since we are going to modify it
                $instanceSegment = ($::.SegmentHelper |=> ToPublicSegment $parser $idSegment $lastPublicSegment).psobject.copy()
                if ( $graphCurrentItem ) {
                    $::.SegmentHelper.AddContent($instanceSegment, $graphCurrentItem)
                    $::.SegmentHelper.GetNewObjectWithMetadata($graphCurrentItem, $instanceSegment)
                } else {
                    $instanceSegment
                }
            }

            $additionalSegments | foreach {
                $metadata = $_.__ItemMetadata()
                if ( ! $segmentTable -or $segmentTable[$metadata.graphElement] ) {

                    if ( $::.SegmentHelper.IsValidLocationClass($metadata.Class) -and ( $metadata.class -ne 'EntityType' ) ) {
                        $nextUris.Enqueue(@($currentDepth, $metadata.GraphUri))
                    }
                } else {
                    write-verbose "$($_.id) already exists in hierarchy $($metadata.graphUri)"
                }
            }

            $results += $additionalSegments
        } elseif ( $Children.ispresent ) {
            $childSegments = $parser |=> GetChildren $lastSegment $validLocationClasses | sort-object Name
        } else {
            if ( $graphCurrentItem ) {
                # Create a new public segment since we are going to modify it
                $lastOutputSegment = ($results | select -last 1).psobject.copy()
                $::.SegmentHelper.AddContent($lastOutputSegment, $graphCurrentItem)
                $objectWithMetadata = $::.SegmentHelper.GetNewObjectWithMetadata($graphCurrentItem, $lastOutputSegment)
                # Replace the segment in the collection with a new one
                # This is a rather convoluted approach :( -- needs a rewrite
                $results[$results.length - 1] = $objectWithMetadata
            }
        }

        if ( $childSegments ) {
            $publicChildSegments = @()
            $childSegments | foreach {
                $meetsLocationRequirement = ! $LocatableChildren.IsPresent -or $::.SegmentHelper.IsValidLocationClass(($_.graphElement |=> GetEntity).Type)
                $meetsNonvirtualRequirement = ! $disallowVirtualChildren -or ! $_.isVirtual
                $skipSegment = ! $meetsLocationRequirement -or ! $meetsNonvirtualRequirement
                if ( ! $skipSegment ) {
                    $publicChildSegments += ($::.SegmentHelper |=> ToPublicSegment $parser $_ $lastPublicSegment)
                }
            }

            if ( $currentDepth -lt $RecursionDepth ) {
                $publicChildSegments | foreach {
                    if ( ! $segmentTable -or ( ! $segmentTable[$_.details.graphElement] ) ) {
                        if ( $::.SegmentHelper.IsValidLocationClass($_.Class) -and ( $_.class -ne 'entitytype') ) {
                            $nextUris.Enqueue(@($currentDepth, $_.GraphUri))
                        }
                    } else {
                        write-verbose "$($_.id) already exists in hierarchy $($_.GraphUri)"
                    }
                }
            }

            $results += $publicChildSegments
        }
    }
    $results
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphUriInfo Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::AnyUri))
