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

. (import-script EntityVertex)

ScriptClass GraphSegment {
    $graphElement = $null
    $leadsToVertex = $false
    $name = $null
    $type = $null
    $isDynamic = $false
    $parent = $null
    $isVirtual = $false
    $isInVirtualPath = $false
    $graphUri = $null
    $decoration = $null

    function __initialize($graphElement, $parent = $null, $instanceName = $null) {
        $this.graphElement = $graphElement
        $this.parent = if ( $parent ) {
            $parent
        } else {
            $::.GraphSegment.RootSegment
        }

        $isVertex = $true
        $this.leadsToVertex = if ( Test-ScriptObject $this.graphElement EntityEdge ) {
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

        $this.name = if ( $isVertex -and ($this.graphElement |=> IsRoot) ) {
            '/'
            } elseif ( $this.leadsToVertex -or ($isVertex -and $this.graphElement.type -eq 'Singleton') ) {
             $this.graphElement.name
        } elseif ( $instanceName ) {
            $this.isDynamic = $true
            $instanceName
        } elseif (! $isVertex -and ! $this.leadsToVertex ) {
            # This is an edge, but instead of leading to a vertex, it leads to another edge
            $this.graphElement.name
        } else {
            $this.isDynamic = $true
            $this.isVirtual = $true
            "{{{0}}}" -f $this.graphElement.name
        }

        $this.isInVirtualPath = $this.isVirtual -or ( $parent -ne $null -and $parent.IsInVirtualPath )
        $this.GraphUri = if ( $this.parent ) {
            $::.GraphUtilities.JoinFragmentUri($this.parent.graphUri, $this.name)
        } else {
            $this.name
        }
    }

    function Decorate($data) {
        if ($this.decoration) {
            throw 'Segment already has decoration data'
        }

        $this.decoration = $data
    }

    function NewVertexSegment($graph, $segmentName, $allowedVertexTypes) {
        if ( ! $this.leadsToVertex ) {
            throw "Vertex segment instance name may not be supplied for '$($this.graphElement.id)', segments are pre-defined"
        }

        $graphElement = if ( Test-ScriptObject $this.graphElement EntityEdge ) {
            if ( $this.GraphElement.sink |=> IsNull ) {
                return $null
            } else {
                $this.GraphElement.sink
            }
        } elseif ( $this.graphElement.type -eq 'EntitySet' ) {
            $typeData = $this.graphElement.entity.typeData
            $graph |=> GetTypeVertex $typeData.EntityTypeName
        } else {
            throw "Unexpected vertex type '$($this.graphElement.type)' for segment '$($segment.name)'"
        }

        if ( ! $graphElement ) {
            throw "Unable to determine element type for '$($this.graphElement)' for segment '$($segment.name)'"
        }

        if ( $allowedVertexTypes -and ($graphElement.Type -notin $allowedVertextypes) ) {
            return $null
        }

        new-so GraphSegment $graphElement $this $segmentName
    }

    function NewTransitionSegments($graph, $segmentName, $allowedTransitionTypes = $null) {
        if ( $this.leadsToVertex ) {
            throw "Current segment $($this.graphElement.name) is static, so next segment must be dynamic"
        }

        $isVertex = Test-ScriptObject $this.graphElement EntityVertex

        $edges = if ( $isVertex ) {
            $localEdges = $graph |=> GetVertexEdges $this.graphElement
            if ( $segmentName -and $segmentName -ne '' ) {
                $localEdges[$segmentName]
            } else {
                $localEdges.values
            }
        } else {
            # This is already an edge, so the next edges come from the sink
            $sinkEdges = $graph |=> GetVertexEdges $this.GraphElement.sink
            if ( ! ( $this.graphElement.sink |=> IsNull ) ) {
                $sinkEdges.values
            }
        }

        $edges | foreach {
            if ( ! $allowedTransitionTypes -or ($_.transition.type -in $allowedTransitionTypes) ) {
                new-so GraphSegment $_ $this
            }
        }
    }

    function NewNextSegments($graph, $segmentName, $allowedTransitionTypes) {
        if ( $this.leadsToVertex ) {
            $newVertex = NewVertexSegment $graph $segmentName $allowedTransitionTypes
            if ( $newVertex ) {
                $newVertex
            } else {
                @()
            }
        } else {
            NewTransitionSegments $graph $segmentName $allowedTransitionTypes
        }
    }

    function IsRoot {
        (Test-ScriptObject $this.GraphElement EntityVertex) -and ($this.GraphElement |=> IsRoot)
    }

    function ToGraphUri($graph = $null) {
        if ( ! $graph ) {
            ToGraphUriFromEndpoint
        } else {
            ToGraphUriFromEndpoint $graph.Endpoint $graph.ApiVersion
        }
    }

    function ToGraphUriFromEndpoint($graphEndpointUri = $null, $graphVersion = $null) {
        $currentSegment = $this

        $relativeUriString = $this.name

        while ($currentSegment.parent -ne $null) {
            $relativeUriString = $::.GraphUtilities.JoinFragmentUri($currentSegment.parent.name, $relativeUriString)
            $currentSegment = $currentSegment.parent
        }

        if ( ! $graphEndpointUri ) {
            $::.GraphUtilities.JoinGraphUri('/', $relativeUriString)
        } else {
            $relativeVersionedUriString = $::.GraphUtilities.JoinRelativeUri($graphVersion, $relativeUriString)
            $::.GraphUtilities.JoinAbsoluteUri($graphEndpointUri, $relativeVersionedUriString)
        }
    }

    static {
        $RootSegment = $null
        $NullSegment = $null
    }
}

$::.GraphSegment.RootSegment = new-so GraphSegment $::.EntityVertex.RootVertex
$::.GraphSegment.NullSegment = new-so GraphSegment $::.Entityvertex.NullVertex
