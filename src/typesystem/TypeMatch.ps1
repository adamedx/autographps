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

ScriptClass TypeMatch {
    $Criteria = $null
    $SearchOptions = $null
    $SearchTerm = $null
    $MatchedTypeName = $null
    $IsExactMatch = $false
    $Score = 0

    static {
        $MatchWeight = @{
            Name = 2
        }
    }

    function __initialize($criterionName, $searchOptions, $searchTerm, $typeName, $isExactMatch) {
        $this.Criteria = @{}
        $this.SearchOptions = $searchOptions
        $this.SearchTerm = $searchTerm
        $this.MatchedTypeName = $typeName
        $this.IsExactMatch = ( $criterionName -eq 'TypeName' ) -and $isExactMatch

        AddCriterion $criterionName
    }

    function AddCriterion($criterionName, $isExactMatch) {
        $this.Criteria.Add($criterionName, [PSCustomObject] @{Name=$criterionName; IsExactMatch = $isExactMatch})
        __UpdateScore
    }

    function SetExactMatch {
        $this.IsExactMatch = $true
        __UpdateScore
    }

    function __UpdateScore {
        $score = 0

        foreach ( $criterionName in $this.Criteria.Keys ) {
            $score += __GetWeight $this.Criteria[$criterionName]
        }

        if ( $this.IsExactMatch ) {
            $score += 100
        }

        $this.score = $score
    }

    function __GetWeight($criterion) {
        $knownWeight = $this.scriptclass.MatchWeight[$criterion.Name]

        $normalizedWeight = if ( $knownWeight ) {
            $knownWeight
        } else {
            1
        }

        if ( $criterion.IsExactMatch ) {
            $normalizedWeight * 2
        } else {
            $normalizedWeight
        }
    }
}
