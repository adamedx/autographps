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
            $uriInfo.FullTypeName
        }

        function DecorateObjectWithType($graphObject, $typeName) {
            $graphObject | add-member -membertype ScriptMethod -name  $this.TYPE_METHOD_NAME -value ([ScriptBlock]::Create("'$typeName'"))
        }

        function GetTypeFromDecoratedObject($graphObject) {
            if ( $graphObject | gm $this.TYPE_METHOD_NAME -erroraction ignore ) {
                $graphObject.($this.TYPE_METHOD_NAME)()
            }
        }

        function GetUriFromDecoratedObject($targetContext, $graphObject) {
            $type = GetTypeFromDecoratedObject $graphObject

            if ( $type ) {
                DefaultUriForType $targetContext $type
            }
        }

        function GetTypeAwareRequestInfo($graphName, $typeName, $fullyQualifiedTypeName, $uri, $typedGraphObject) {
            $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

            $targetUri = $uri

            $targetType = if ( $typeName ) {
                $resolvedType = Get-GraphType $TypeName -TypeClass Entity -GraphName $graphName -FullyQualifiedTypeName:$fullyQualifiedTypeName -erroraction stop
                $targetUri = DefaultUriForType $targetContext $resolvedType.TypeId

                if ( ! $targetUri ) {
                    throw "Unable to find URI for type '$typeName' -- explicitly specify the target URI and retry."
                }

                $resolvedType.typeId
            } elseif ($uri)  {
                TypeFromUri $uri
            } elseif ( $typedGraphObject ) {
                $objectUri = GetUriFromDecoratedObject $targetContext $typedGraphObject
                if ( $objectUri ) {
                    $targetUri = $objectUri
                }
            }

            if ( ! $targetUri ) {
                throw [ArgumentInvalidException]::new('Either a type name or URI must be specified')
            }

            [PSCustomObject] @{
                Context = $targetContext
                TypeName = $targetType
                Uri = $targetUri
            }
        }
    }
}
