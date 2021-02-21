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

ScriptClass TypeSearchResultDisplayType {
    $Score = $null
    $TypeClass = $null
    $TypeId = $null
    $Criteria = $null
    $MatchedTerms = $null
    $GraphName = $null

    function __initialize($typeMatch, $graphName) {
        $this.Score = $typeMatch.Score
        $this.TypeClass = $typeMatch.MatchedTypeClass
        $this.TypeId = $typeMatch.MatchedTypeName
        $this.Criteria = $typeMatch.MatchedTerms.Keys
        $this.MatchedTerms = $typeMatch.MatchedTerms.Values
        $this.GraphName = $graphName
    }

    static {
        function __RegisterDisplayType {
            $displayTypeName = $this.ClassName

            $displayProperties = @('TypeClass', 'TypeId', 'Criteria', 'MatchedTerms')

            remove-typedata -typename $displayTypeName -erroraction ignore

            $displayTypeArguments = @{
                TypeName = $displayTypeName
                DefaultDisplayPropertySet = $displayProperties
            }

            Update-TypeData -force @displayTypeArguments
        }
    }
}


$::.TypeSearchResultDisplayType |=> __RegisterDisplayType
