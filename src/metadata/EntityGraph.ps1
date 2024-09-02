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

. (import-script Entity)
. (import-script EntityVertex)
. (import-script EntityEdge)
. (import-script GraphBuilder)

ScriptClass EntityGraph {
    $ApiVersion = $null
    $Endpoint = $null
    $vertices = $null
    $rootVertices = $null
    $typeVertices = $null
    $typeToSetMapping = $null
    $defaultNamespace = $null
    $dataModel = $null
    $builder = $null
    $id = $null

    function __initialize($defaultNamespace, $apiVersion = 'localtest', [Uri] $endpoint = 'http://localhost', $dataModel) {
        $this.defaultNamespace = $defaultNamespace
        $this.vertices = @{}
        $this.rootVertices = @{}
        $this.typeVertices = @{}
        $this.typeToSetMapping = @{}
        $this.ApiVersion = $apiVersion
        $this.Endpoint = $endpoint
        $this.dataModel = $dataModel
        $this.builder = new-so GraphBuilder $endpoint $apiVersion $dataModel
        $this.id = [guid]::newguid()
    }

    function GetRootVertices {
        $this.rootVertices
    }

    function AddVertex($entity) {
        $vertex = new-so EntityVertex $entity
        $this.vertices.Add($vertex.id, $vertex)
        if ( $vertex.type -eq 'EntityType' ) {
            $this.typeVertices.Add(($vertex.typeName), $vertex)
        } elseif ( $vertex.type -eq 'EntitySet' -or $vertex.type -eq 'Singleton' ) {
            $this.rootVertices.Add($vertex.name, $vertex)
            if ( $vertex.type -eq 'EntitySet' ) {
                __AddEntityTypeToEntitySetMapping $entity.typeData.TypeName $entity.name
            }
        }
    }

    function TypeVertexFromTypeName($typeName) {
        $typeData = $::.GraphUtilities.ParseTypeName($typeName)

        $this.typeVertices[$typeData.TypeName]
    }

    function GetTypeVertex($qualifiedTypeName) {
        $vertex = TypeVertexFromTypeName $qualifiedTypeName

        if ( ! $vertex ) {
            __AddTypeVertex $qualifiedTypeName
            $vertex = TypeVertexFromTypeName $qualifiedTypeName
        }

        if ( ! $vertex ) {
            throw "Vertex '$qualifiedTypeName' not found"
        }

        __UpdateVertex $vertex

        $vertex
    }

    function GetVertexEdges($vertex) {
        __UpdateVertex $vertex
        $vertex.outgoingEdges
    }

    function GetEntityTypeToEntitySetMapping($entityTypeName) {
        $this.typeToSetMapping[$entityTypeName]
    }

    function GetDefaultNamespace {
        $this.defaultNamespace
    }

    function UnaliasQualifiedName($typeName) {
        $this.dataModel.UnaliasQualifiedName($typeName)
    }

    function GetEnumTypes {
        $this.dataModel |=> GetEnumTypes
    }

    function GetEntityTypes {
        $this.dataModel |=> GetEntityTypes
    }

    function GetComplexTypes {
        $this.dataModel |=> GetComplexTypes
    }

    function GetMethodsForType($qualifiedTypeName) {
        $this.dataModel.GetMethodBindingsForType($qualifiedTypeName)
    }

    function __AddInheritedEdgesToTypeVertex($typeVertex) {
        $baseTypeName = $typeVertex.baseTypeName

        while ( $baseTypeName -and $baseTypeName -ne 'graph.entity' -and $baseTypeName -ne 'microsoft.graph.entity' ) {
            $unaliasedBaseTypeName = UnaliasQualifiedName $baseTypeName
            $baseTypeVertex = GetTypeVertex $unaliasedBaseTypeName
            $baseTypeName = if ( $baseTypeVertex ) {
                foreach ( $edge in $baseTypeVertex.outgoingEdges.values ) {
                    $newEdge = new-so EntityEdge $baseTypeVertex $edge.sink $edge.transition
                    if ( ! ( $typeVertex.EdgeExists($newEdge.name) ) ) {
                        $typeVertex.AddEdge($newEdge)
                    }
                }
                $baseTypeVertex.baseTypeName
            }
        }
    }

    function __UpdateVertex($vertex) {
        if ( ! (__IsVertexComplete $vertex) ) {
            Write-Progress -id 2 -activity "Updating vertex '$($vertex.name)'" -ParentId 1
            if ( $vertex.entity.type -eq 'Singleton' -or $vertex.entity.type -eq 'EntitySet' ) {
                __AddTypeVertex $vertex.entity.typedata.typename
            }
            __AddTypeForVertex $vertex
            Write-Progress -id 2 -activity "Vertex '$($vertex.name)' successfully updated" -completed
        }
    }

    function __AddTypeForVertex($vertex) {
        $this.builder.AddEdgesToVertex($this, $vertex, $true)
        __AddInheritedEdgesToTypeVertex $vertex
    }

    function __AddTypeVertex($qualifiedTypeName) {
        $vertex = TypeVertexFromTypeName $qualifiedTypeName
        if ( ! $vertex ) {
            $this.builder.AddEntityTypeVertices($this, $qualifiedTypeName)
            $newTypeVertex = TypeVertexFromTypeName $qualifiedTypeName
            __AddInheritedEdgesToTypeVertex $newTypeVertex
        }
    }

    function __IsVertexComplete($vertex) {
        $vertex.TestFlags($::.GraphBuilder.AllBuildFlags) -eq $::.GraphBuilder.AllBuildFlags
    }

    function __AddEntityTypeToEntitySetMapping($entityTypeName, $entitySetName) {
        $existingMapping = $this.typeToSetMapping[$entityTypeName]
        if ( $existingMapping ) {
            if ( $existingMapping -ne $entitySetName ) {
                throw "Conflicting entity set '$entitySetName' cannot be added for type '$entityTypeName' because the type is already mapped to '$existingMapping'"
            }
        } else {
            $this.typeToSetMapping.Add($entityTypeName, $entitySetName)
        }
    }

    static {
        $nullVertex = new-so EntityVertex $null

        function NewGraph($endpoint, $version, $schemadata) {
            $dataModel = new-so GraphDataModel $schemadata
            $graph = new-so EntityGraph ($dataModel |=> GetDefaultNamespace) $version $Endpoint $dataModel

            $graph.builder |=> InitializeGraph $graph

            $graph
        }
    }
}
