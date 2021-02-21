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

. (import-script TypeMatch)
. (import-script TypeTable)

ScriptClass TypeSearcher {
    $typeTable = $null

    function __initialize($typeProviders) {
        $this.typeTable = new-so TypeTable $typeProviders
    }

    function Search($searchFields) {
        $typeMatches = @{}
        foreach ( $field in $searchFields ) {
            $fieldMatches = $this.typeTable |=> FindTypeInfoByField $field.Name $field.SearchTerm $field.TypeClasses $field.LookupClass

            foreach ( $match in $fieldMatches ) {
                $existingMatch = $typeMatches[$match.MatchedTypeName]
                if ( $existingMatch ) {
                    $existingMatch |=> Merge $match
                } else {
                    $typeMatches.Add($match.MatchedTypeName, $match)
                }
            }
        }

        $typeMatches.Values
    }
}
