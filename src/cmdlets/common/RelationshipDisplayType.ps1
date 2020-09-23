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

ScriptClass RelationshipDisplayType {
    $GraphName = $null
    $Relationship = $null
    $FromUri = $false
    $TargetUri = $null
    $TargetId = $null

    function __initialize($graphName, $relationship, $fromUri, $targetUri, $targetId) {
        $this.GraphName = $graphName
        $this.Relationship = $relationship
        $this.FromUri = $fromUri
        $this.TargetUri = $targetUri
        $this.TargetId = $targetId
    }

    static {
        function __RegisterDisplayType {
            $displayTypeName = $this.ClassName

            $displayProperties = @('Relationship', 'TargetId', 'FromUri', 'TargetUri')

            remove-typedata -typename $displayTypeName -erroraction ignore

            $displayTypeArguments = @{
                TypeName = $displayTypeName
                DefaultDisplayPropertySet = $displayProperties
            }

            Update-TypeData -force @displayTypeArguments
        }
    }
}

$::.RelationshipDisplayType |=> __RegisterDisplayType
