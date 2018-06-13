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

. (import-script Entity)

ScriptClass EntityVertex {
    $id = $null
    $name = $null
    $entity = $null
    $type = $null
    $outgoingEdges = $null
    $typeName = $null

    function __initialize($entity) {
        $this.entity = $entity

        if ( $entity ) {
            $this.outgoingEdges = @{}
            $this.type = $entity.type
            $this.name = $entity.Name
            $this.id = $entity |=> GetEntityId
            $this.typeName = $entity.typedata.EntityTypeName
        } else {
            $this.type = 'Null'
            $this.name = 'Null'
        }

        $this.scriptclass.count = $this.scriptclass.count + 1
    }

    function IsNull {
        $this.type -eq 'Null'
    }

    function IsRoot {
        $this.type -eq '__Root'
    }

    function AddEdge($edge) {
        $this.outgoingEdges.Add($edge.name, $edge)
    }

    function EdgeExists($entityName) {
        $this.outgoingEdges.ContainsKey($entityName)
    }

    function GetResultTypeData {
        if ( $this.entity ) {
            $this.entity.typeData
        } else {
            @{EntityTypeName='Null';IsCollection=$false}
        }
    }

    function GetEntity {
        $this.entity
    }

    static {
        $count = 0
        $NullVertex = $null
        $ScalarVertex = $null
        $RootVertex = $null
    }
}

$::.EntityVertex.NullVertex = new-so EntityVertex $null
$::.EntityVertex.ScalarVertex = new-so EntityVertex (new-so Entity ([PSCustomObject] @{Name='scalar';LocalName='__Scalar'}))
$::.EntityVertex.RootVertex = new-so EntityVertex (new-so Entity ([PSCustomObject] @{Name='root';LocalName='__Root'}))
