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
            [Uri] "/$entitySet"
        }

        function TypeFromUri([Uri] $uri) {
            $uriInfo = Get-GraphUri $Uri -erroraction stop
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
                if ( $id -and ! $objectUri.tostring().tolower().EndsWith("/$($id.tolower())") ) {
                    $objectUri = $objectUri, $id -join '/'
                }

                $objectUri
            }
        }

        function GetTypeFromDecoratedObject($graphObject) {
            if ( $graphObject | gm -membertype scriptmethod $this.TYPE_METHOD_NAME -erroraction ignore ) {
                $graphObject.($this.TYPE_METHOD_NAME)()
            }
        }

        function GetUriFromDecoratedObject($targetContext, $graphObject) {
            $objectUri = GetUriFromDecoratedResponseObject $targetContext $graphObject

            if ( ! $objectUri ) {
                $type = GetTypeFromDecoratedObject $graphObject

                if ( $type ) {
                    $objectUri = DefaultUriForType $targetContext $type
                }
            }

            $objectUri
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
                    throw "Unable to find URI for type '$typeName' -- explicitly specify the target URI and retry."
                }

                [PSCustomObject] @{
                    FullTypeName = $resolvedType.typeId
                    IsCollection = $false
                }
            } elseif ( $uri )  {
                TypeFromUri $uri
            } elseif ( $typedGraphObject ) {
                $objectUri = GetUriFromDecoratedObject $targetContext $typedGraphObject $id
                if ( $objectUri ) {
                    $targetUri = $objectUri

                    # TODO: When an object is supplied, it had better end with whatever id was supplied.
                    # This will not always be true of the uri retrieved from the object
                    if ( $id -and ! $targetUri.tostring().tolower().EndsWith("/$($id.tolower())") ) {
                        $targetUri = $targetUri, $id -join '/'
                    }
                    TypeFromUri $targetUri
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
                Uri = $targetUri
            }
        }

        function ToGraphAbsoluteUri($targetContext, [Uri] $graphRelativeUri) {
            $uriString = $targetContext.connection.graphendpoint.graph.tostring(), $targetContext.version, $graphRelativeUri.tostring().trimstart('/') -join '/'
            [Uri] $uriString
        }
    }
}
