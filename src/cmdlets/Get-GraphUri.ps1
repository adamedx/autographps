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

$SegmentDisplayTypeName = 'GraphSegmentDisplayType'

function Get-GraphUri {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)]
        [Uri] $uri = $null,

        [Switch] $Parents
    )

    $context = $::.GraphContext |=> GetCurrent

    $parser = new-so SegmentParser $context
    $segments = $parser |=> SegmentsFromUri $uri
    $count = if ( $Parents.ispresent ) {
        $segments.length
    } else {
        1
    }

    $segments | select -last $count | foreach {
        __ToPublicSegment $parser $_
    }
}

function __ToPublicSegment($parser, $segment) {
    $graph = $parser.graph
    $Uri = $segment |=> ToGraphUri $graph
    $entity = $segment.graphElement |=> GetEntity
    $namespace = $entity.namespace
    $namespaceDelimited = $namespace + '.'
    $resultTypeData = $segment.graphElement |=> GetResultTypeData
    $parent = $segment.parent

    $isCollection = $resulttypeData.IsCollection -eq $true
    $fullTypeName = $resultTypeData.EntityTypeName
    $shortTypeName = if ( $fullTypeName.ToLower().StartsWith($namespaceDelimited.tolower()) ) {
        $fullTypeName.Substring($namespaceDelimited.length)
    } else {
        $fullTypeName
    }
    $parentPath = if ( $parent ) { $parent |=> ToGraphUri $graph }

    [PSCustomObject] @{
        PSTypeName = $SegmentDisplayTypeName
        Parent = $parentPath
        Collection = $isCollection
        Type = $shortTypeName
        Name = $segment.name
        Namespace = $namespace
        Uri = $Uri
        FullTypeName = $fullTypeName
        Version = $graph.apiversion
        Endpoint = $graph.endpoint
        IsDynamic = $segment.isDynamic
        Details = $segment
    }
}

function RegisterSegmentDisplayType {
    remove-typedata -typename $SegmentDisplayTypeName -erroraction silentlycontinue

    $coreProperties = @( 'Collection', 'Type', 'Parent', 'Name')

    $segmentDisplayTypeArguments = @{
        TypeName    = $segmentDisplayTypeName
        MemberType  = 'NoteProperty'
        MemberName  = 'PSTypeName'
        Value       = $SegmentDisplayTypeName
        DefaultDisplayPropertySet = $coreProperties
    }

    Update-TypeData -force @segmentDisplayTypeArguments
}

RegisterSegmentDisplayType
