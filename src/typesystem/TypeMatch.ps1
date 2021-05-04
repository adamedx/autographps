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
    $SearchTerm = $null
    $MatchedTypeName = $null
    $MatchedTypeClass = $null
    $MatchedTerms = $null
    $Score = 0

    static {
        $MatchWeight = @{
            Name = 16
            Property = 8
            NavigationProperty = 4
            Method = 2
        }
    }

    function __initialize($criterionName, $searchTerm, $typeName, $matchedTypeClass, [string[]] $matchedTerms) {
        $this.Criteria = [ordered] @{}
        $this.SearchTerm = $searchTerm
        $this.MatchedTypeName = $typeName
        $this.MatchedTypeClass = $matchedTypeClass
        $this.MatchedTerms = @{$criterionName=$matchedTerms}

        $isExactMatch = $searchTerm -in $matchedTerms

        AddCriterion $criterionName $isExactMatch
    }

    function AddCriterion([string] $criterionName, $isExactMatch) {
        $this.Criteria.Add($criterionName, [PSCustomObject] @{Name=$criterionName;IsExactMatch=$isExactMatch})
        __UpdateScore
    }

    function SetExactMatch($criterionKey) {
        if ( $this.Criteria[$criterionKey] ) {
            $this.Criteria[$criterionKey].IsExactMatch = $true
        }

        __UpdateScore
    }

    function Merge($other) {
        if ( $this.MatchedTypeName -ne $other.MatchedTypeName ) {
            throw "TypeMatch for type '$($other.MatchedTypeName)' may not be merged with source TypeMatch '$($this.MatchedTypeName)'"
        }

        foreach ( $criterionKey in $other.Criteria.Keys ) {
            $existingCriteria = $this.Criteria[$criterionKey]
            if ( ! $existingCriteria ) {
                $this.Criteria.Add($criterionKey, [PSCustomObject] @{Name=$criterionKey; IsExactMatch = $false})
            }
        }

        foreach ( $matchedCriterion in $other.matchedTerms.Keys ) {
            $otherMatch = $other.matchedTerms[$matchedCriterion]

            if ( ! $this.matchedTerms[$matchedCriterion] ) {
                $this.matchedTerms[$matchedCriterion] = $otherMatch
            }
        }

        __UpdateScore
    }

    function __UpdateScore {
        $score = $this.Criteria.Count

        foreach ( $criterionName in $this.Criteria.Keys ) {
            $score += __GetWeight $this.Criteria[$criterionName]
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
