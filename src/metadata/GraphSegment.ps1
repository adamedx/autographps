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

ScriptClass GraphSegment {
    $graphElement = $null
    $leadsToVertex = $false
    $name = $null
    $type = $null
    $isDynamic = $false

    function __initialize($graphElement, $instanceName = $null) {
        $this.graphElement = $graphElement

        $isVertex = $true
        $this.leadsToVertex = if ( $this.graphElement.pstypename -eq 'EntityEdge' ) {
            $isVertex = $false
            if ( $instanceName ) {
                throw "An instance name '$instanceName' was specified for an edge, which already has a name"
            }
            $this.type = $this.graphElement.transition.type
            # If this is one to many, then the next element is an individual vertex. Otherwise,
            # the node is another (named) transition
            $this.graphElement.oneToMany
        } else {
            $this.type = ($this.graphElement.type)
            $this.graphElement.type -eq 'EntitySet'
        }

        $this.name = if ( $this.leadsToVertex -or ($isVertex -and $this.graphElement.type -eq 'Singleton') ) {
             $this.graphElement.name
        } elseif ( $instanceName ) {
            $this.isDynamic = $true
            $instanceName
        } elseif (! $isVertex -and ! $this.leadsToVertex ) {
            # This is an edge, but instead of leading to a vertex, it leads to another edge
            $this.graphElement.name
        } else {
            $this.isDynamic = $true
            "{{{0}}}" -f $this.graphElement.name
        }
    }

    function NewVertexSegment($graph, $segmentName) {
        if ( ! $this.leadsToVertex ) {
            throw "Vertex segment instance name may not be supplied for '$($this.graphElement.id)', segments are pre-defined"
        }

        $graphElement = if ( test-scriptobject $this.graphElement EntityEdge ) {
            if ( $this.GraphElement.sink |=> IsNull ) {
                return $null
            } else {
                $this.GraphElement.sink
            }
        } elseif ( $this.graphElement.type -eq 'EntitySet' ) {
            $typeData = $this.graphElement.entity |=> GetEntityTypeData
            $graph |=> TypeVertexFromTypeName $typeData.EntityTypeName
        } else {
            throw "Unexpected vertex type '$($this.graphElement.type)' for segment '$($segment.name)'"
        }

        if ( ! $graphElement ) {
            throw "Unable to determine element type for '$($this.graphElement)' for segment '$($segment.name)'"
        }

        new-so GraphSegment $graphElement $segmentName
    }

    function NewTransitionSegments($segmentName) {
        if ( $this.leadsToVertex ) {
            throw "Current segment $($this.graphElement.name) is static, so next segment must be dynamic"
        }

        $isVertex = $this.graphElement.pstypename -eq 'EntityVertex'

        $edges = if ( $isVertex ) {
            if ( $segmentName -and $segmentName -ne '' ) {
                $this.graphElement.outGoingEdges[$segmentName]
            } else {
                $this.graphElement.outGoingEdges.values
            }
        } else {
            # This is already an edge, so the next edges come from the sink
            if ( ! ( $this.graphElement.sink |=> IsNull ) ) {
                $this.graphElement.sink.outgoingEdges.values
            }
        }

        $edges | foreach {
            new-so GraphSegment $_
        }
    }

    function NewNextSegments($graph, $segmentName) {
        if ( $this.leadsToVertex ) {
            $newVertex = NewVertexSegment $graph $segmentName
            if ( $newVertex ) {
                $newVertex
            } else {
                @()
            }
        } else {
            NewTransitionSegments $segmentName
        }
    }
}
