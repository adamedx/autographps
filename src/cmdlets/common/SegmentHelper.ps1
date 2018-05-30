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

. (import-script ..\..\common\GraphUtilities)

ScriptClass SegmentHelper {
    static {
        const SegmentDisplayTypeName 'GraphSegmentDisplayType'

        function __initialize {
            __RegisterSegmentDisplayType
        }

        function IsValidLocationClass($itemClass) {
            switch ( $itemClass ) {
                '__Root' { $true }
                'Singleton' { $true }
                'EntitySet' { $true }
                'EntityType' { $true }
                'NavigationProperty' { $true }
                default { $false }
            }
        }

        function UriToSegments($parser, [Uri] $uri) {
            $graphUri = if ( $uri.IsAbsoluteUri ) {
                $graphRelativeUri = ''
                for ( $uriIndex = 2; $uriIndex -lt $uri.segments.length; $uriIndex++ ) {
                    $graphRelativeUri += $uri.segments[$uriIndex]
                }
                $graphRelativeUri
            } else {
                $uri
            }

            $parser |=> SegmentsFromUri $graphUri
        }

        function ToPublicSegment($parser, $segment, $parentPublicSegment) {
            $graph = $parser.graph
            $Uri = $segment.ToGraphUri($graph)
            $entity = $segment.graphElement |=> GetEntity
            $namespace = $entity.namespace
            $namespaceDelimited = $namespace + '.'
            $resultTypeData = $segment.graphElement.GetResultTypeData()
            $parentSegment = $segment.parent
            $entityClass = $entity.Type
            $isCollection = $entity.typeData.IsCollection -eq $true

            # Use the return type, which for vertices is the self, but
            # for edges is the vertex to which the self leads
            $fullTypeName = if ( $resultTypeData ) {
                $resultTypeData.EntityTypeName
            } else {
                ''
            }

            $shortTypeName = if ( $fullTypeName.ToLower().StartsWith($namespaceDelimited.tolower()) ) {
                $fullTypeName.Substring($namespaceDelimited.length)
            } else {
                $fullTypeName
            }

            $parentPath = if ( $parentSegment ) { $parentSegment.ToGraphUri($null) }
            $relativeUri = $segment.ToGraphUri($null)

            $path = $::.GraphUtilities |=> ToLocationUriPath $parser.context $relativeUri

            $relationship = if ( $segment.isdynamic -or $entityClass -eq 'Singleton' ) {
                'Data'
            } elseif ( $iscollection ) {
                'Collection'
            } else {
                'Direct'
            }

            [PSCustomObject]@{
                PSTypeName = $this.SegmentDisplayTypeName
                ParentPath = $parentPath
                Relation = $relationship
                Collection = $isCollection
                Class = $entityClass
                Type = $shortTypeName
                Name = $segment.name
                Namespace = $namespace
                Uri = $Uri
                GraphUri = $relativeUri
                Path = $path
                FullTypeName = $fullTypeName
                Version = $graph.apiversion
                Endpoint = $graph.endpoint
                IsDynamic = $segment.isDynamic
                Parent = $ParentPublicSegment
                Details = $segment
                Content = $null
            }
        }

        function ToPublicSegmentFromGraphItem( $parentPublicSegment, $graphItem ) {
            $fullTypeName = ($::.Entity |=> GetEntityTypeDataFromTypeName $parentPublicSegment.Type).EntityTypeName
            $typeComponents = $fullTypeName -split '\.'
            [PSCustomObject]@{
                PSTypeName = $parentPublicSegment.pstypename
                ParentPath = $parentPublicSegment.Path
                Relation = 'Direct'
                Collection = $false
                Class = 'EntityType'
                Type = $typeComponents[$typeComponents.length - 1]
                Name = $graphItem.Id
                Namespace = $parentPublicSegment.Namespace
                Uri = new-object Uri $parentPublicSegment.Uri, $graphItem.id
                GraphUri = $::.GraphUtilities.JoinGraphUri($parentPublicSegment.GraphUri, $graphItem.id)
                Path = $::.GraphUtilities.JoinFragmentUri($parentPublicSegment.path, $graphItem.Id)
                FullTypeName = $fullTypeName
                Version = $parentPublicSegment.Version
                Endpoint = $parentPublicSegment.Endpoint
                IsDynamic = $true
                Parent = $ParentPublicSegment
                Details = $null
                Content = $_
            }
        }

        function __RegisterSegmentDisplayType {
            remove-typedata -typename $this.SegmentDisplayTypeName -erroraction silentlycontinue

            $coreProperties = @('Relation', 'Class', 'Type', 'Name')

            $segmentDisplayTypeArguments = @{
                TypeName    = $this.segmentDisplayTypeName
                MemberType  = 'NoteProperty'
                MemberName  = 'PSTypeName'
                Value       = $this.SegmentDisplayTypeName
                DefaultDisplayPropertySet = $coreProperties
            }

            Update-TypeData -force @segmentDisplayTypeArguments
        }
    }
}

$::.SegmentHelper |=> __initialize
