# Copyright 2020, Adam Edwards
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

ScriptClass TypeUriHelper {
    static {
        const TYPE_METHOD_NAME __ItemType

        function DefaultUriForType($targetContext, $entityTypeName) {
            $entitySet = $::.GraphManager |=> GetGraph $targetContext |=> GetEntityTypeToEntitySetMapping $entityTypeName
            if ( $entitySet ) {
                [Uri] "/$entitySet"
            }
        }

        function TypeFromUri([Uri] $uri, $targetContext) {
            $uriInfo = Get-GraphUriInfo $Uri -GraphScope $targetContext.name -erroraction stop
            [PSCustomObject] @{
                FullTypeName = $uriInfo.FullTypeName
                IsCollection = $uriInfo.Collection
                UriInfo = $uriInfo
            }
        }

        function DecorateObjectWithType($graphObject, $typeName) {
            $graphObject | add-member -membertype ScriptMethod -name  $this.TYPE_METHOD_NAME -value ([ScriptBlock]::Create("'$typeName'"))
        }

        function GetUriFromDecoratedResponseObject($targetContext, $responseObject, $resourceId) {
            # This method handles two cases:
            #
            #   * Objects returned by Get-GraphResource which are decorated with the __ItemContext scriptmethod
            #   * Oboject returned by Get-GraphResourceWithMetadata which are PSCustomObjects of GraphSgementDisplayType
            #
            # The latter has a Path member with exactly the uri needed to resolve the object, the other requires
            # a workaround since it may only have a partial URI originally used as the target of a POST that created it.

            if ( $responseObject | gm -membertype scriptmethod __ItemContext -erroraction ignore ) {
                $requestUri = $::.GraphUtilities |=> ParseGraphUri $responseObject.__ItemContext().RequestUri $targetContext
                $objectUri = $requestUri.GraphRelativeUri

                # When an object is supplied, its URI had better end with whatever id was supplied.
                # This will not always be true of the uri retrieved from the object because this URI is the
                # URI that was used to request the object from Graph, not necessarily the object's actual
                # URI. For example, a request to POST to /groups will return an object located at
                # /groups/9318e52c-6cd7-430e-9095-a54aa5754381. But __ItemContext contains the URI that was
                # used to make the POST request, i.e. /groups. However, since the id is supplied to this method,
                # we can recover the URI if we assume the discrepancy is indeed due to this scenario.
                # TODO: Get an explicit object URI from the object itself rather than this workaround which
                # will have problematic corner cases.
                if ( $resourceId -and ! $objectUri.tostring().tolower().EndsWith("/$($resourceId.tolower())") ) {
                    $objectUri = $objectUri.tostring(), $resourceId -join '/'
                }

                $objectUri.tostring()
            } elseif ( ( $responseObject -is [PSCustomObject] ) -and ( $responseObject.psobject.typenames -contains 'GraphSegmentDisplayType' ) ) {
                $responseObject.GraphUri.tostring()
            }
        }

        function GetTypeFromDecoratedObject($graphObject) {
            if ( $graphObject | gm -membertype scriptmethod $this.TYPE_METHOD_NAME -erroraction ignore ) {
                $graphObject.($this.TYPE_METHOD_NAME)()
            }
        }

        function GetUriFromDecoratedObject($targetContext, $graphObject, $noInterpolation = $false) {
            $idHint = if ( ! $noInterpolation -and ( $graphObject | gm id -erroraction ignore ) ) {
                $graphObject.id
            }

            $objectUri = GetUriFromDecoratedResponseObject $targetContext $graphObject $idHint
            if ( ! $objectUri ) {
                $type = GetTypeFromDecoratedObject $graphObject

                if ( $type ) {
                    $objectUri = DefaultUriForType $targetContext $type
                }
            }

            $objectUri
        }

        function IsValidEntityType($typeName, $graphContext, $isFullyQualified) {
            $typeManager = $::.TypeManager |=> Get $graphContext
            ( $typeManager |=> FindTypeDefinition Entity $typeName $isFullyQualified ) -ne $null
        }

        function GetTypeAwareRequestInfo($graphName, $typeName, $fullyQualifiedTypeName, $uri, $id, $typedGraphObject) {
            $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

            $targetUri = if ( $uri ) {
                $::.GraphUtilities |=> ToGraphRelativeUri $uri $targetContext
            }

            $targetTypeInfo = if ( $typeName ) {
                $resolvedType = Get-GraphType $TypeName -TypeClass Entity -GraphName $graphName -FullyQualifiedTypeName:$fullyQualifiedTypeName -erroraction stop
                $typeUri = DefaultUriForType $targetContext $resolvedType.TypeId

                if ( $typeUri ) {
                    $targetUri = $typeUri, $id -join '/'
                } else {
                    throw "Unable to find URI for type '$typeName' -- explicitly specify the target URI or an existing item and retry."
                }

                [PSCustomObject] @{
                    FullTypeName = $resolvedType.typeId
                    IsCollection = $true
                }
            } elseif ( $uri )  {
                TypeFromUri $targetUri $targetContext
            } elseif ( $typedGraphObject ) {
                $objectUri = GetUriFromDecoratedObject $targetContext $typedGraphObject $id
                if ( $objectUri ) {
                    $objectUriInfo = TypeFromUri $objectUri $targetContext

                    # TODO: When an object is supplied, it had better end with whatever id was supplied.
                    # This will not always be true of the uri retrieved from the object
                    if ( $id -and ( $objectUriInfo.UriInfo.class -in ( 'EntityType', 'EntitySet' ) ) -and ( ! $targetUri -or ! $targetUri.tostring().tolower().EndsWith("/$($id.tolower())") ) ) {
                        $correctedUri = $objectUri, $id -join '/'
                        $objectUriInfo = TypeFromUri $correctedUri $targetContext
                    }

                    $targetUri = $objectUriInfo.UriInfo.graphUri
                    $objectUriInfo
                }
            }

            if ( ! $targetUri ) {
                throw [ArgumentException]::new('Either a type name or URI must be specified')
            }

            [PSCustomObject] @{
                Context = $targetContext
                TypeName = $targetTypeInfo.FullTypeName
                IsCollection = $targetTypeInfo.IsCollection
                TypeInfo = $targetTypeInfo
                Uri = $targetUri.tostring().trimend('/')
            }
        }

        function ToGraphAbsoluteUri($targetContext, [Uri] $graphRelativeUri) {
            $uriString = $targetContext.connection.graphendpoint.graph.tostring().trimend('/'), $targetContext.version, $graphRelativeUri.tostring().trimstart('/') -join '/'
            [Uri] $uriString
        }

        function GetReferenceSourceInfo($graphName, $typeName, $isFullyQualifiedTypeName, $id, $uri, $graphObject, $navigationProperty)  {
            $fromId = if ( $Id ) {
                $Id
            } elseif ( $GraphObject -and ( $GraphObject | gm -membertype noteproperty id -erroraction ignore ) ) {
                $GraphObject.Id # This is needed when an object is supplied without an id parameter
            }

            $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $isFullyQualifiedTypeName $uri $fromId $GraphObject

            $segments = @()
            $segments += $requestInfo.uri.tostring()
            if ( $navigationProperty -and $requestInfo.uri ) {
                $segments += $navigationProperty
            }

            $sourceUri = $segments -join '/'

            [PSCustomObject] @{
                Uri = $sourceUri
                RequestInfo = $requestInfo
            }
        }

        function GetReferenceTargetTypeInfo($graphName, $requestInfo, $navigationProperty, $overrideTargetTypeName, $allowCollectionTarget) {
            $targetTypeName = $OverrideTargetTypeName

            $isCollection = $false

            if ( $navigationProperty ) {
                $targetPropertyInfo = if ( ! $OverrideTargetTypeName -or $allowCollectionTarget ) {
                    $targetType = Get-GraphType -GraphName $graphName $requestInfo.TypeName
                    $targetTypeInfo = $targetType.NavigationProperties | where name -eq $navigationProperty

                    if ( ! $targetTypeInfo ) {
                        return $null
                    }

                    $isCollection = $targetTypeInfo.IsCollection
                    $targetTypeInfo
                }

                if ( ! $targetTypeName ) {
                    $targetTypeName = $targetPropertyInfo.TypeId
                }
            }

            [PSCustomObject] @{
                TypeId = $targetTypeName
                IsCollectionTarget = $isCollection
            }
        }

        function GetReferenceTargetInfo($graphName, $targetTypeName, $isFullyQualifiedTypeName, $targetId, $targetUri, $targetObject, $allowCollectionTarget = $false) {
            if ( $TargetUri ) {
                foreach ( $destinationUri in $TargetUri ) {
                    $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $destinationUri $null $null
                }
            } elseif ( $TargetObject ) {
                $targetObjectId = if ( $TargetObject | gm id -erroraction ignore ) {
                    $TargetObject.id
                } else {
                    throw "An object specified for the 'TargetObject' parameter does not have an Id field; specify the object's URI or the TypeName and Id parameters and retry the command"
                }
                # The assumption here is that anything that can be a target must be able to be referenced as part of an entityset.
                # This generally seems to be true.
                $::.TypeUriHelper |=> GetTypeAwareRequestInfo $graphName $targetTypeName $isFullyQualifiedTypeName $null $targetObjectId $null
            } else {
                foreach ( $destinationId in $targetId ) {
                    $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $targetTypeName $isFullyQualifiedTypeName $null $destinationId $null
                }
            }
        }
    }
}
