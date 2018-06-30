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
            $itemClass -in $this.GetValidLocationClasses()
        }

        function GetValidLocationClasses {
            @(
                '__Root'
                'Singleton',
                'EntitySet',
                'EntityType',
                'NavigationProperty'
            )
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

            if ( $segment.decoration ) {
                return $segment.decoration
            }

            $Uri = $segment.ToGraphUriFromEndpoint($parser.context.connection.GraphEndpoint.Graph, $parser.context.Version)
            $entity = $segment.graphElement |=> GetEntity
            $namespace = if ( $entity ) { $entity.namespace } else {'Null' }
            $namespaceDelimited = $namespace + '.'
            $resultTypeData = $segment.graphElement.GetResultTypeData()
            $parentSegment = $segment.parent
            $entityClass = if ( $entity ) { $entity.Type } else { 'Null' }
            $isCollection = if ( $entity ) { $entity.typeData.IsCollection -eq $true } else { $false }

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

            $info = $this.__GetInfoField($isCollection, $segment.isDynamic, $entityClass, $false)

            $result = [PSCustomObject] @{
                PSTypeName = $this.SegmentDisplayTypeName
                ParentPath = $parentPath
                Info = $info
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
                Version = $parser.context.version
                Endpoint = $parser.context.connection.graphEndpoint.Graph
                IsDynamic = $segment.isDynamic
                Parent = $ParentPublicSegment
                Details = $segment
                Content = $null
            }

            $segment |=> Decorate $result
            $result
        }

        function ToPublicSegmentFromGraphItem( $parentPublicSegment, $graphItem ) {
            $fullTypeName = ($::.Entity |=> GetEntityTypeDataFromTypeName $parentPublicSegment.Type).EntityTypeName
            $typeComponents = $fullTypeName -split '\.'

            # Objects may actually be raw json, or even binary, depending
            # on callers specifying that they don't want objects, but the
            # raw content value from the Graph web response
            $Id = $graphItem | select -expandproperty id -erroraction silentlycontinue

            $itemId = if ( $Id ) {
                $Id
            } else {
                '[{0}]' -f $graphItem.Gettype().name
            }

            [PSCustomObject] @{
                PSTypeName = $parentPublicSegment.pstypename
                ParentPath = $parentPublicSegment.Path
                Info = $this.__GetInfoField($false, $true, 'EntityType', $true)
                Relation = 'Direct'
                Collection = $false
                Class = 'EntityType'
                Type = $typeComponents[$typeComponents.length - 1]
                Name = $itemId
                Namespace = $parentPublicSegment.Namespace
                Uri = new-object Uri $parentPublicSegment.Uri, $itemId
                GraphUri = $::.GraphUtilities.JoinGraphUri($parentPublicSegment.GraphUri, $itemId)
                Path = $::.GraphUtilities.JoinFragmentUri($parentPublicSegment.path, $itemId)
                FullTypeName = $fullTypeName
                Version = $parentPublicSegment.Version
                Endpoint = $parentPublicSegment.Endpoint
                IsDynamic = $true
                Parent = $ParentPublicSegment
                Details = $null
                Content = $graphItem
            }
        }

        function AddContent($publicSegment, $content) {
            if ($publicSegment.content) {
                throw "Segment $($publicSegment.name) already has content"
            }

            $publicSegment.content = $content
            $publicSegment.Info = $this.__GetInfoField($false, $true, 'EntityType', $true)
        }

        function __GetInfoField($isCollection, $isDynamic, $entityClass, $hasContent) {
            $info = 0..2
            $info[0] = if ( $isCollection ) { '*' } else { ' ' }
            $info[1] = if ( $hasContent ) { '+' } else { ' ' }
            $info[2] = if ( $this.IsValidLocationClass($entityClass ) ) { '>' } else { ' ' }
            $info -join ''
        }

        function __RegisterSegmentDisplayType {
            remove-typedata -typename $this.SegmentDisplayTypeName -erroraction silentlycontinue

            $coreProperties = @('Info', 'Class', 'Type', 'Name')

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
