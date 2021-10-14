# Copyright 2021, Adam Edwards
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

. (import-script ..\..\common\PreferenceHelper)

add-type -TypeDefinition @'
    namespace AutoGraph.Model {
        public class GraphObject {
            public GraphObject(object metadata) {
                this.__itemMetadata = metadata;
            }

            public object __ItemMetadata() { return this.__itemMetadata; }

            object __itemMetadata;
        }
    }
'@

ScriptClass SegmentHelper {
    static {
        const SegmentDisplayTypeName 'GraphSegmentDisplayType'
        const MetadataMethodName __ItemMetadata

        function __initialize {
            # NOTE: There are one or more ps1xml files that defines display formats for this type based on
            # on the PSTypeName. That may override behaviors like default columns defined here, though other
            # aspects like serialization behavior should be preserved as the ps1xml options are *merged*
            # with exisitng options. In particular the ps1xml file provides the ability to emit a "title row"
            # to the display for DOS dir-style "directory listings" like PowerShell's Get-ChildItem command.
            # This allows us to use this type to provide an ls-like user experience when navigating the Graph.
            # Primarily for this reason the ps1xml is included. These files are enabled through the
            # 'FormatsToProcess' field of the module manifest, but can also be dynamically updated through
            # Update-FormatData.
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

        function IsGraphSegmentType($object) {
            $object -is [PSCustomObject] -and $object.pstypenames.contains($SegmentDisplayTypeName)
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
                $resultTypeData.TypeName
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

            # Seems like ScriptClass constants have a strange behavior when used as a typename here.
            # To work around this, use ToString()
            $result = [PSCustomObject] @{
                PSTypeName = ($this.SegmentDisplayTypeName.tostring())
                ParentPath = $parentPath
                Info = $info
                Name = $segment.name
                Relation = $relationship
                Collection = $isCollection
                Class = $entityClass
                Type = $shortTypeName
                TypeId = $fullTypeName
                Id = $segment.name
                Namespace = $namespace
                AbsoluteUri = $Uri
                GraphName = $parser.context.name
                GraphUri = $relativeUri
                Path = $path
                FullTypeName = $fullTypeName
                Version = $parser.context.version
                Endpoint = $parser.context.connection.graphEndpoint.Graph
                IsDynamic = $segment.isDynamic
                Parent = $ParentPublicSegment
                Details = $segment
                Content = $null
                Preview = $null
            }

            $segment |=> Decorate $result
            $result
        }

        function ToPublicSegmentFromGraphItem( $graphContext, $graphItem, $requestSegment ) {
            $typeInfo = $::.TypeUriHelper |=> InferTypeUriInfoFromRequestItem $requestSegment $graphItem

            $fullTypeName = $typeInfo.FullTypeName

            $typeComponents = $fullTypeName -split '\.'

            # Objects may actually be raw json, or even binary, depending
            # on callers specifying that they don't want objects, but the
            # raw content value from the Graph web response
            $Id = $graphItem | select -expandproperty id -erroraction ignore

            $itemName = if ( $Id ) {
                $Id
            } else {
                '[{0}]' -f $graphItem.Gettype().name
            }

            $itemId = if ( $graphItem -is [PSCustomObject] -and $graphItem.pstypenames.contains('GraphSegmentDisplayType') -and ($graphItem.Content) ) {
                $graphItem.Content.Id
            } else {
                $itemName
            }

            # Using ToString() here to work around a strange behavior where
            # PSTypeName does not cause type conversion
            $result = [PSCustomObject] @{
                PSTypeName = $requestSegment.pstypename.tostring()
                ParentPath = $requestSegment.Path
                Info = $this.__GetInfoField($false, $true, 'EntityType', $true)
                Name = $itemName
                Relation = 'Direct'
                Collection = $false
                Class = 'EntityType'
                Type = $typeComponents[$typeComponents.length - 1]
                TypeId = $fullTypeName
                Id = $itemId
                Namespace = $requestSegment.Namespace
                AbsoluteUri = $typeInfo.AbsoluteUri
                GraphName = $graphContext.Name
                GraphUri = $typeinfo.GraphUri
                Path = $typeInfo.FullPath
                FullTypeName = $fullTypeName
                Version = $requestSegment.Version
                Endpoint = $requestSegment.Endpoint
                IsDynamic = $true
                Parent = $null
                Details = $null
                Content = $graphItem
                Preview = $this.__GetPreview($graphItem, $itemId)
            }

            if ( $fullTypeName -and $graphItem ) {
                GetNewObjectWithMetadata $graphItem $result
            } else {
                $result
            }
        }

        function ToPublicSegmentFromGraphResponseObject( $graphContext, $graphObject ) {
            $typeInfo = $::.TypeUriHelper |=> InferTypeUriInfoFromRequestItem $null $graphObject

            $absoluteUri = $null
            $locationUriPath = $null

            if ( $typeInfo.GraphUri ) {
                $absoluteUri = $graphContext.Connection.GraphEndpoint.Graph, $graphContext.Version, $typeInfo.GraphUri
                $locationUriPath = $::.GraphUtilities |=> ToLocationUriPath $graphContext $typeInfo.GraphUri
            }

            $fullTypeName = $typeInfo.FullTypeName

            $typeComponents = $fullTypeName -split '\.'

            # Objects may actually be raw json, or even binary, depending
            # on callers specifying that they don't want objects, but the
            # raw content value from the Graph web response
            $Id = $graphObject | select -expandproperty id -erroraction ignore

            $itemName = if ( $Id ) {
                $Id
            } elseif ( $fullTypeName )  {
                $fullTypeName
            } else {
                '[{0}]' -f $graphObject.GetType().Name
            }

            $itemId = if ( $graphObject -is [PSCustomObject] -and $graphObject.pstypenames.contains('GraphSegmentDisplayType') -and ($graphObject.Content) ) {
                $graphObject.Content.Id
            } else {
                $itemName
            }

            $namespace = if ( $fullTypeName ) {
                $components = $fullTypeName -split '\.'
                $length = (, $components).length -2
                if ( $length -gt 0 ) {
                    $components[0..$length] -join '.'
                } else {
                    $fullTypeName
                }
            }

            # Using ToString() here to work around a strange behavior where
            # PSTypeName does not cause type conversion
            $result = [PSCustomObject] @{
                PSTypeName = ($this.SegmentDisplayTypeName.tostring())
                ParentPath = $null
                Info = $this.__GetInfoField($false, $true, 'EntityType', $true)
                Name = $itemName
                Relation = 'Direct'
                Collection = $false
                Class = 'EntityType'
                Type = $typeComponents[$typeComponents.length - 1]
                TypeId = $fullTypeName
                Id = $itemId
                Namespace = $namespace
                AbsoluteUri = $absoluteUri
                GraphName = $graphContext.Name
                GraphUri = $typeinfo.GraphUri
                Path = $locationUriPath
                FullTypeName = $fullTypeName
                Version = $graphContext.Version
                Endpoint = $graphContext.Connection.GraphEndpoint
                IsDynamic = $true
                Parent = $null
                Details = $null
                Content = $graphObject
                Preview = $this.__GetPreview($graphObject, $itemId)
            }

            if ( $fullTypeName -and $graphObject ) {
                GetNewObjectWithMetadata $graphObject $result
            } else {
                $result
            }
        }

        function AddContent($publicSegment, $content) {
            if ($publicSegment.content) {
                throw "Segment $($publicSegment.id) already has content"
            }

            if ($publicSegment.Preview) {
                throw "Segment $($publicSegment.id) already has a Preview"
            }

            if ( $content | gm id -erroraction ignore ) {
                $publicSegment.Id = $content.id
            }

            $publicSegment.content = $content
            $publicSegment.Preview = $this.__GetPreview($content, $publicSegment.name)
            $publicSegment.Info = $this.__GetInfoField($false, $true, 'EntityType', $true)
        }

        function GetNewObjectWithMetadata($graphItem, $segmentMetadata) {
            $wrappedObject = [AutoGraph.Model.GraphObject]::new($segmentMetadata)

            foreach ( $property in $graphItem.psobject.properties ) {
                $wrappedObject.psobject.properties.Add($property, $true)
            }

            $itemContext = $graphItem.psobject.methods | where Name -eq __ItemContext

            if ( $itemContext ) {
                $wrappedObject.psobject.methods.Add($itemContext[0], $true)
            }

            # When an item is returned as part of a heterogeneous collection, it should have
            # an '@odata.type'. In this case, to ensure that table formatting is sensible,
            # we lower the priority of the type so that it uses a more generic type that
            # shows less specific but common information for any type.
            $specificTypeIndex = if ( $graphItem | gm '@odata.type' -erroraction ignore ) {
                1
            } else {
                0
            }

            $wrappedObject.pstypenames.insert(0, 'GraphResponseObject')
            $wrappedObject.pstypenames.insert(0, 'AutoGraph.Entity')
            $wrappedObject.pstypenames.insert($specificTypeIndex, "AutoGraph.Entity.$($segmentMetadata.TypeId)")
            $wrappedObject
        }

        function __GetPreview($content, $defaultValue) {
            $previewProperties = $content | select Name, DisplayName, Title, FileName, Subject, Topic, Id, bodyPreview
            if ( $previewProperties.Name ) {
                $previewProperties.Name
            } elseif ( $previewProperties.DisplayName ) {
                $previewProperties.DisplayName
            } elseif ( $previewProperties.Title ) {
                $previewProperties.Title
            } elseif ( $previewProperties.FileName ) {
                $previewProperties.FileName
            } elseif ( $previewProperties.Subject ) {
                $previewProperties.Subject
            } elseif ( $previewProperties.Topic ) {
                $previewProperties.Topic
            } elseif ( $previewProperties.bodyPreview ) {
                $previewproperties.bodyPreview
            } elseif ( $previewProperties.Id ) {
                $previewProperties.Id
            } else {
                $defaultValue
            }
        }

        function __GetInfoField($isCollection, $isDynamic, $entityClass, $hasContent) {
            $info = 0..3
            $info[0] = $this.__EntityClassToSymbol($entityClass)
            $info[1] = if ( $isCollection ) { '*' } else { ' ' }
            $info[2] = if ( $hasContent ) { '+' } else { ' ' }
            $info[3] = if ( $this.IsValidLocationClass($entityClass ) ) { '>' } else { ' ' }
            $info -join ''
        }

        function __EntityClassToSymbol($entityClass) {
            switch ($entityClass) {
                'EntityType'         { 't' }
                'NavigationProperty' { 'n' }
                'EntitySet'          { 'e' }
                'Singleton'          { 's' }
                'Function'           { 'f' }
                'Action'             { 'a' }
                'Null'               { '-' }
                '__Root'             { '/' }
                default              { '?' }
            }
        }

        function __RegisterSegmentDisplayType {
            remove-typedata -typename $this.SegmentDisplayTypeName -erroraction ignore

            $coreProperties = @('Info', 'Type', 'Preview', 'Id')

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
