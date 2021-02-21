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
    $sortedTypeNames = $null
    $typeTable = $null

    static {
        $Matchers = @{
            Name = {param($searcher, $criterion, $searchTerm, $typeClasses, $lookupClass) $searcher |=> __Search $criterion $typeClasses $searchTerm $lookupClass}
        }
    }

    function __initialize( $typeProviders, $sortedTypeNames ) {
<#
        $this.sortedTypeNames = [System.Collections.Generic.SortedList[string,string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ( $typeName in $sortedTypeNames ) {
            $this.sortedTypeNames.Add($typeName, $typeName)
        }
#>
        $this.typeTable = new-so TypeTable $typeProviders Entity, Complex, Enumeration $sortedTypeNames
        <#
        $indices = foreach ( $provider in $typeProviders ) {
            $provider |=> GetTypeIndexes Name, Property, NavigationProperty, Method
        }
        $this.typeTable = new-so TypeTable $indices Entity, Complex, Enumeration $sortedTypeNames
#>
    }

    function Search($searchFields) {
        $typeMatches = @{}
        foreach ( $field in $searchFields ) {
            $fieldMatches = __Search $field.Name $field.TypeClasses $field.SearchTerm $field.LookupClass

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

    function __Search($criterion, [string[]] $typeClasses, $searchTerm, $lookupClass) {
        $this.typeTable |=> FindTypeInfoByField $criterion $searchTerm $typeClasses $lookupClass
    }

    function __InitializeTypeTable {
<#        $indices = foreach ( $provider in $typeProviders ) {
            $provider |=> GetTypeIndexes Name, Property, NavigationProperty, Method
        }#>
#        $this.typeTable = new-so TypeTable $this.typeProviders Entity, Complex, Enumeration $sortedTypeNames
    }

    function __MatchName($searchTerm, $exactMatch, $searchOptions) {
        if ( $exactMatch ) {
            if ( $this.sortedTypeNames[$searchTerm] ) {
                new-so TypeMatch Name $searchOptions $searchTerm $searchTerm $true
            }
        } else {
            $filter = '*{0}*' -f $searchTerm
            foreach ( $typeName in $this.sortedTypeNames.keys ) {
                $isExactMatch = $typeName -eq $searchTerm

                if ( $isExactMatch -or ( $typeName -like $filter ) ) {
                    new-so TypeMatch Name $searchOptions $searchTerm $typeName $isExactMatch
                }
            }
        }
    }
}
