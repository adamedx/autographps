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

. (import-script common/SegmentHelper)
. (import-script ../common/GraphUtilities)

function Get-GraphUri {
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

        [parameter(parametersetname='FromObject')]
        [String] $GraphScope = $null,

        [parameter(parametersetname='FromObjectParents', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='FromObjectChildren', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='FromObject', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject[]]$GraphItems
    )

    # This is not very honest -- we're using valuefrompipeline, but
    # only to signal the presence of input -- we use $input because
    # unless you use BEGIN, END, PROCESS blocks, you can't actually
    # iterate the parameter -- $input is a way around that
    $inputs = if ( $graphItems ) {
        $input
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

    $context = if ( $GraphScope ) {
        $::.Logicalgraphmanager.Get().contexts[$GraphScope].context
    }

    while ( $nextUris.Count -gt 0 ) {
        $currentItem = $nextUris.Dequeue()
        $currentDepth = $currentItem[0] + 1
        $currentUri = $currentItem[1]

        $graphItem = if ($GraphItems) {
            $currentUri
        }

        $uriSource = $currentUri
        $inputUri = if ( $graphItem ) {
            $unparsedUri = if ( $graphItem | gm -membertype scriptmethod '__ItemContext' ) {
                [Uri] ($graphItem |=> __ItemContext | select -expandproperty RequestUri)
            } elseif ( $graphItem | gm uri ) {
                $uriSource = $graphItem.uri
                [Uri] $uriSource
            } else{
                throw "Object type does not support Graph URI source"
            }
            $parsedUri = $::.GraphUtilities |=> ParseGraphUri $unparsedUri
            $context = $parsedUri.MatchedContext
            $parsedUri.GraphRelativeUri
        } else {
            $parsedLocation = $::.ContextHelper |=> ParseGraphRelativeLocation $currentUri
            $context = $parsedLocation.context
            $parsedLocation.GraphRelativeUri
        }

        $parser = new-so SegmentParser $context $null ($graphItems -ne $null)

        write-verbose "Uri '$uriSource' translated to '$inputUri'"

        if ( $IgnoreMissingMetadata.IsPresent -and (($::.GraphContext |=> GetMetadataStatus $context) -ne [MetadataStatus]::Ready) ) {
            return $::.SegmentHelper |=> ToPublicSegment $parser $::.GraphSegment.NullSegment
        }

        $segments = $::.SegmentHelper |=> UriToSegments $parser $inputUri
        $lastSegment = $segments | select -last 1

        $segmentTable = $null
        if ( $NoCycles.IsPresent ) {
            $segmentTable = @{}
            $segments | foreach { $segmentTable.Add($_.graphElement, $_) }
        }

        $instanceId = if ( $GraphItem ) {
            $typeData = ($lastSegment.graphElement |=> GetEntity).typedata
            if ( $typeData.IsCollection ) {
                if ( $graphItem | gm -membertype noteproperty id ) {
                    $graphItem.id
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
            $idSegment = $lastSegment |=> NewNextSegments ($context |=> GetGraph) $instanceId $validLocationClasses

            $additionalSegments = if ( $Children.IsPresent ) {
                $childSegments = $parser |=> GetChildren $idSegment $validLocationClasses | sort Name
            } else {
                # Create a new public segment since we are going to modify it
                $instanceSegment = ($::.SegmentHelper |=> ToPublicSegment $parser $idSegment $lastPublicSegment).psobject.copy()
                if ( $graphItem ) {
                    $::.SegmentHelper.AddContent($instanceSegment, $graphItem)
                }
                $instanceSegment
            }

            $additionalSegments | foreach {
                if ( ! $segmentTable -or $segmentTable[$_.graphElement] ) {
                    if ( $::.SegmentHelper.IsValidLocationClass($_.Class) -and ( $_.class -ne 'EntityType' ) ) {
                        $nextUris.Enqueue(@($currentDepth, $_.GraphUri))
                    }
                } else {
                    write-verbose "$($_.name) already exists in hierarchy $($_.GraphUri)"
                }
            }

            $results += $additionalSegments
        } elseif ( $Children.ispresent ) {
            $childSegments = $parser |=> GetChildren $lastSegment $validLocationClasses | sort Name
        } else {
            if ( $GraphItem ) {
                # Create a new public segment since we are going to modify it
                $lastOutputSegment = ($results | select -last 1).psobject.copy()
                $::.SegmentHelper.AddContent($lastOutputSegment, $graphItem)
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
                        write-verbose "$($_.name) already exists in hierarchy $($_.GraphUri)"
                    }
                }
            }

            $results += $publicChildSegments
        }
    }
    $results
}

