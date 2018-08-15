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

. (import-script GraphSegment)

ScriptClass UriCache {
    $uriTable = strict-val ([ordered] @{}).gettype() $null
    $maxEntries = 3

    function __initialize($maxEntries = $null) {
        $this.maxEntries = if ( $maxEntries ) { $maxEntries } else { 100 }
        $this.uriTable = [ordered] @{}
    }

    function Clear {
        $this.uriTable.Clear()
    }

    function AddUriForSegments($segments, $cacheEntities = $false, $parentSegment = $null) {
        $segments | foreach {

            $cacheable = ($_ -ne $null) -and (! $_.isDynamic -or $cacheEntities)

            if ( $cacheable ) {
                $segmentUri = $_.graphUri

                if ( ! $this.uriTable[$segmentUri] ) {
                    write-verbose "Adding uri '$segmentUri' to uri cache"
                    if ( $this.uriTable.count -ge $this.maxEntries ) {
                        $removed = $this.uriTable.Remove( ($this.uriTable.keys | select -first 1) )
                        write-verbose "Removing uri '$removed' from cache due to maximum entries reached"
                    }
                    $this.UriTable.Add($segmentUri, @{Segment=$_;Children=$null})
                }
            }
        }

        if ( $parentSegment -and ( ! $parentSegment.isDynamic -or $cacheEntities ) ) {
            $parentEntry = $this.uriTable[$parentSegment.graphUri]
            if ( $parentEntry -and $parentEntry.Children -eq $null ) {
                $parentEntry.Children = $segments
            }
        }
    }

    function GetSegmentFromParent($parentSegment, $childSegmentName) {
        $targetUri = if ( $parentSegment ) {
            $::.GraphUtilities.JoinFragmentUri($parentSegment.graphUri, $childSegmentName)
        } else {
            '/' + $childSegmentName
        }

        $result = GetSegmentFromUri $targetUri
        if ( ! $result ) {
            write-verbose "Uri '$targetUri' not found in uri cache"
        }
        $result
    }

    function GetSegmentFromUri($uri) {
        $result = __GetSegmentDataFromUri($uri)
        if ( $result ) {
            $result.Segment
        }
    }

    function GetChildSegmentsFromUri($uri) {
        $result = __GetSegmentDataFromUri($uri)
        if ( $result ) {
            $result.Children
        }
    }

    function __GetSegmentDataFromUri($uri) {
        $result = $this.uriTable[$uri]
        if ( $result ) {
            $this.uriTable.Remove($result.Segment.graphUri) | out-null
            $this.uriTable.Add($result.Segment.GraphUri, $result)
            $result
        }
    }
}
