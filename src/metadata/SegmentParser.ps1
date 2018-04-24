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

. (import-script GraphBuilder)
. (import-script GraphSegment)

ScriptClass SegmentParser {
    $graph = $null

    function __initialize($apiVersion, $connection, $existingGraph) {
        $this.graph = if ( $existingGraph ) {
            $existingGraph
        } else {
            $graph = $::.GraphBuilder |=> GetGraph $apiVersion $connection
            $graph
        }
    }

    function GetChildren($segment) {
        if ( $segment -eq $null ) {
            $childVertices = $this.graph |=> GetRootVertices
            $childVertices.values | foreach {
                new-so GraphSegment $_
            }
        } else {
            $segment |=> NewNextSegments $this.graph
        }
    }

    function SegmentsFromUri([Uri] $uri, $enforceDynamicSegments = $false ) {
        $unescapedPath = [Uri]::UnescapeDataString($uri.tostring())

        $segmentStrings = $unescapedPath -split '/'

        $segments = @()
        $lastSegment = $null

        $segmentStrings | foreach {
            $targetSegmentName = $_
            $currentSegments = GetChildren $lastSegment

            if ( ! $currentSegments ) {
                throw "No children found for '$($lastSegment.name)'"
            }

            $matchingSegment = $null
            if ( ! $enforceDynamicSegments -and ( $currentSegments -isnot [object[]] ) ) {
                $matchingSegment = new-so GraphSegment $currentSegments[0].graphElement $targetSegmentName
            } else {
                $matchingSegment = $currentSegments | where {
                    $_.name -eq $targetSegmentName
                }

                if ( ! $matchingSegment ) {
                    $parentName = if ( $lastSegment ) {
                        $lastSegment.name
                    } else {
                        '<root>'
                    }
                    throw "No matching child segment '$targetSegmentName' under segment '$parentName'"
                }
            }
            $lastSegment = $matchingSegment

            $segments += $lastSegment
        }

        $segments
    }

    function ToPublicSegment($segment) {
        [PSCustomObject] @{
            PSTypeName = $SegmentDisplayTypeName
            Name = $segment.name
            Type = $segment.Type
            Version = $this.graph.apiversion
            Endpoint = $this.graph.endpoint
            IsDynamic = $segment.isDynamic
            Details = $segment
        }
    }
}
