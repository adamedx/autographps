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
            $uriInfo = Get-GraphUriInfo $Uri -GraphName $targetContext.name -erroraction stop
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
            #   * Objects returned by Get-GraphResourceWithMetadata which are PSCustomObjects of GraphSgementDisplayType
            #
            # The latter has a Path member with exactly the uri needed to resolve the object, the other requires
            # a workaround since it may only have a partial URI originally used as the target of a POST that created it.

            if ( ( $responseObject -is [PSCustomObject] ) -and ( $responseObject.psobject.typenames -contains 'GraphSegmentDisplayType' ) ) {
                $responseObject.GraphUri.tostring()
            } else {
                # Try to parse the odata context

                $itemContext = if ( $responseObject | gm -membertype scriptmethod __ItemContext -erroraction ignore ) {
                    $responseObject.__ItemContext()
                }

                # The IsCollectionMember property of itemContext cannot always be trusted -- for our use case
                # we ignore this for entities. TODO: Address this in the context itself so we can actually trust the property
                $objectUri = if ( ! $itemContext -or ! ( $itemContext.IsEntity -and $itemContext.IsCollectionMember ) ) {
                    $::.GraphUtilities |=> GetAbstractUriFromResponseObject $responseObject $true $resourceId
                }

                # If the odata context is not parseable for some reason or we do not trust it, fall back to older and slower logic
                if ( ! $objectUri -and $itemContext ) {
                    $requestUri = $::.GraphUtilities |=> ParseGraphUri $itemContext.RequestUri $targetContext
                    $objectUri = $requestUri.GraphRelativeUri
                    $uriInfo = if ( $resourceId ) {
                        Get-GraphUriInfo $objectUri
                    }

                    # When an object is supplied, its URI had better end with whatever id was supplied.
                    # This will not always be true of the uri retrieved from the object because this URI is the
                    # URI that was used to request the object from Graph, not necessarily the object's actual
                    # URI. For example, a request to POST to /groups will return an object located at
                    # /groups/9318e52c-6cd7-430e-9095-a54aa5754381. But __ItemContext contains the URI that was
                    # used to make the POST request, i.e. /groups. However, since the id is supplied to this method,
                    # we can recover the URI if we assume the discrepancy is indeed due to this scenario.
                    # TODO: Get an explicit object URI from the object itself rather than this workaround which
                    # will have problematic corner cases.
                    if ( $uriInfo -and $uriInfo.Collection -and $resourceId -and ! $objectUri.tostring().tolower().EndsWith("/$($resourceId.tolower())") ) {
                        $objectUri = $objectUri.tostring(), $resourceId -join '/'
                    }
                }

                if ( ! $objectUri ) {
                    throw 'Unable to determine the Graph URI for the specified object'
                }

                $objectUri.tostring()
            }
        }

        function GetTypeFromDecoratedObject($graphObject) {
            if ( $graphObject | gm -membertype scriptmethod $this.TYPE_METHOD_NAME -erroraction ignore ) {
                $graphObject.($this.TYPE_METHOD_NAME)()
            }
        }

        function InferTypeUriInfoFromRequestItem($requestItem, $responseObject) {
            $absoluteUri = $null
            $fullPath = $null
            $graphUri = $null
            $typeSpecifier = $::.GraphUtilities |=> GetOptionalTypeFromResponseObject $responseObject
            $fullTypeName = if ( $typeSpecifier ) {
                $typeData = $::.GraphUtilities.ParseTypeName($typeSpecifier)
                $typeData.TypeName
            }

            if ( $requestItem ) {
                $absoluteUri = $requestItem.AbsoluteUri
                $fullPath = $requestItem.Path
                $graphUri = $requestItem.GraphUri
                if ( ! $fullTypeName ) {
                    $fullTypeName = $requestItem.FullTypeName
                }

                if ( $requestItem.Collection ) {
                    $absoluteUri = $absoluteUri.trimend('/'), $responseObject.Id -join '/'
                    $fullPath = $fullPath.trimend('/'), $responseObject.Id -join '/'
                    $graphUri = [Uri] ($graphUri.tostring().trimend('/'), $responseObject.Id -join '/')
                }
            } else {
                $graphUri = $::.GraphUtilities |=> GetAbstractUriFromResponseObject $responseObject $true
            }

            [PSCustomObject] @{
                FullTypeName = $fullTypeName
                AbsoluteUri = $absoluteUri
                FullPath = $fullPath
                GraphUri = $graphUri
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

        function GetTypeAwareRequestInfo($graphName, $typeName, $fullyQualifiedTypeName, $uri, $id, $typedGraphObject, $ignoreTypeIfObjectPresent, $targetUriOptional) {
            $metadata = if ( $typedGraphObject -and ( $typedGraphObject | gm __ItemMetadata -erroraction ignore ) ) {
                $typedGraphObject.__ItemMetadata()
            }

            $targetGraphName = if ( $metadata ) {
                $metadata.Graphname
            } else {
                $graphName
            }

            $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $targetGraphName

            $targetUri = if ( $uri ) {
                $::.GraphUtilities |=> ToGraphRelativeUri $uri $targetContext
            } elseif ( $metadata ) {
                $metadata.GraphUri
            }

            $targetTypeInfo = if ( $typeName -and ( ! $typedGraphObject -or $ignoreTypeIfObjectPresent ) ) {
                $remappedTypeClass = if ( $targetUriOptional ) {
                    'Any'
                } else {
                    # We only need to enforce entity if we expect a default URI
                    'Entity'
                }

                $resolvedType = Get-GraphType $TypeName -TypeClass $remappedTypeClass -GraphName $targetContext.Name -FullyQualifiedTypeName:$fullyQualifiedTypeName -erroraction stop
                $typeUri = DefaultUriForType $targetContext $resolvedType.TypeId

                if ( $typeUri ) {
                    $targetUri = $typeUri, $id -join '/'
                } elseif ( ! $targetUriOptional )  {
                    throw "Unable to find URI for type '$typeName' -- explicitly specify the target URI or an existing item and retry."
                }

                [PSCustomObject] @{
                    FullTypeName = $resolvedType.typeId
                    IsCollection = $true
                }
            } elseif ( $uri -and ! ( $ignoreTypeIfObjectPresent -and $typedGraphObject ) )  { # TODO: just increase precedence of metadata (i.e. typedGraphObject) over uri
                TypeFromUri $targetUri $targetContext
            } elseif ( $typedGraphObject ) {
                if ( $metadata -and $::.SegmentHelper.IsGraphSegmentType($metadata) ) {
                    # This is already a fully described object -- no need to make expensive
                    # calls to parse metadata and understand the object
                    $objectUri = $metadata.GraphUri
                    $targetUri = $objectUri
                    [PSCustomObject] @{
                        FullTypeName = $metadata.FullTypeName
                        IsCollection = $metadata.Collection
                        UriInfo = $metadata
                    }
                } else {
                    # We need to analyze information about the object using its uri since we
                    # don't have existing information -- this is expensive, so hopefully
                    # it doesn't occur to often
                    $objectUri = GetUriFromDecoratedObject $targetContext $typedGraphObject $id

                    if ( $objectUri ) {
                        $objectUriInfo = TypeFromUri $objectUri $targetContext

                        # TODO: When an object is supplied, it had better end with whatever id was supplied.
                        # This will not always be true of the uri retrieved from the object because of some
                        # corner cases with the commands used to get objects from the graph, particularly
                        # when an object is retrieved as part of a collection URI -- such URIs do not
                        # contain an id, they end with the parent segment. Another case where this happens
                        # is if the object was created through a POST, though that should definitely be
                        # fixed in the command that creates objects.
                        if ( $id -and ! $objectUri.tostring().tolower().EndsWith("/$($id.tolower())" ) ) {
                            if ( $objectUriInfo.UriInfo.class -in 'EntityType', 'EntitySet' ) {
                                $correctedUri = $objectUri, $id -join '/'
                                $objectUriInfo = TypeFromUri $correctedUri $targetContext
                            } elseif ( $objectUriInfo.UriInfo.class -ne 'Singleton' ) {
                                # TODO: Refine this condition to avoid possibly invalid assumptions.
                                # The object was probably obtained via POST or by enumerating an object collection,
                                # so we'll just assume it's safe to concatenate the id. However, once the corner cases
                                # are corrected in the object decoration, we should update to reliable logic.
                                $itemContext = if ( $typedGraphObject | Get-Member -MemberType ScriptMethod __ItemContext -erroraction ignore ) {
                                    $typedGraphObject.__ItemContext()
                                }

                                $assumeNotCollectionMember = if ( $itemContext ) {
                                    $itemContext.IsEntity -and $itemContext.IsCollectionMember
                                }

                                # Detect the case where we have a navigation to a single entity (not a collection
                                # that contained this element)
                                if ( ! $assumeNotCollectionMember ) {
                                    $correctedUri = $objectUri, $id -join '/'
                                    $objectUriInfo = TypeFromUri $correctedUri $targetContext
                                }
                            }
                        }

                        $targetUri = $objectUriInfo.UriInfo.graphUri
                        $objectUriInfo
                    }
                }
            }

            $targetUriString = if ( $targetUri ) {
                $targetUri.tostring().trimend('/')
            } elseif ( ! $targetUriOptional ) {
                throw [ArgumentException]::new('Either a type name or URI must be specified')
            }

            [PSCustomObject] @{
                Context = $targetContext
                TypeName = $targetTypeInfo.FullTypeName
                IsCollection = $targetTypeInfo.IsCollection
                TypeInfo = $targetTypeInfo
                Uri = $targetUriString
            }
        }

        function ToGraphAbsoluteUri($targetContext, [Uri] $graphRelativeUri) {
            $uriString = $targetContext.connection.graphendpoint.graph.tostring().trimend('/'), $targetContext.version, $graphRelativeUri.tostring().trimstart('/') -join '/'
            [Uri] $uriString
        }

        function GetReferenceSourceInfo($graphName, $typeName, $isFullyQualifiedTypeName, $id, $uri, $graphObject, $navigationProperty, $relationshipInfo)  {
            $fromId = if ( $Id ) {
                $Id
            } elseif ( $graphObject -and ( $graphObject | gm -membertype noteproperty id -erroraction ignore ) ) {
                $graphObject.Id # This is needed when an object is supplied without an id parameter
            }

            $requestInfo = if ( $relationshipInfo ) {
                $::.TypeUriHelper |=> GetTypeAwareRequestInfo $relationshipInfo.GraphName $null $false $relationshipInfo.FromUri $null $null
            } else {
                $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $isFullyQualifiedTypeName $uri $fromId $graphObject
            }

            $segments = @()
            $segments += $requestInfo.uri.tostring()

            $targetNavigation = if ( $RelationshipInfo ) {
                $relationshipInfo.Relationship
            } else {
                $navigationProperty
            }

            if ( $targetNavigation -and $requestInfo.uri ) {
                $segments += $targetNavigation
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
                    $targetTypeInfo = $targetType.Relationships | where name -eq $navigationProperty

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

        function GetReferenceTargetInfo($graphName, $targetTypeName, $isFullyQualifiedTypeName, $targetId, $targetUri, $targetObject, $allowCollectionTarget = $false, $relationshipInfo) {
            if ( $relationshipInfo ) {
                $::.TypeUriHelper |=> GetTypeAwareRequestInfo $relationshipInfo.GraphName $null $false $relationshipInfo.TargetUri $relationshipInfo.TargetId $null
            } elseif ( $TargetUri ) {
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
                    $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $targetTypeName $isFullyQualifiedTypeName $null $destinationId $null $false
                }
            }
        }
    }
}
