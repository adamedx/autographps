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

. (import-script TypeIndex)

ScriptClass TypeTable {
    # Ths class allows for fast lookup of types based on specific
    # fields in the metadata of the types, including the names, properties,
    # and methods of the types. The quick lookup us implemented by
    # indexing these fields.

    $types = $null
    $typeProviders = $null
    $indexes = $null

    function __initialize([HashTable] $typeProviders) {
        $this.types = [System.Collections.Generic.SortedDictionary[string, object]]::new(([System.StringComparer]::OrdinalIgnoreCase))
        $this.indexes = @{}
        $this.typeProviders = $typeProviders

        # Create empty indexes for each desired field
        'Name', 'Property', 'NavigationProperty', 'Method' | foreach {
            $index = new-so TypeIndex $_
            $this.indexes.Add($_, @{Index=$index;Initialized=@{}})
        }
    }

    function FindTypeInfoByField([TypeIndexClass] $indexClass, $lookupValue, [string[]] $classes, [TypeIndexLookupClass] $lookupClass = 'Exact') {
        $searchMethod = switch ( $lookupClass ) {
            'Exact' { 'Find' }
            'StartsWith' { 'FindStartsWith' }
            'Contains' { 'FindContains' }
            default {
                throw "Unkonwn lookup class '$lookupClass'"
            }
        }

        $indexInfo = $this.indexes[$indexClass.tostring()]
        __InitializeIndexForTypeClasses $indexInfo $classes

        $indexInfo.Index |=> $searchMethod $lookupValue $classes
    }

    function AddType($typeId, $class, $schema) {
        $entry = __NewEntry $typeId $class $schema
        __AddEntry $typeId $entry
    }

    function __InitializeIndexForTypeClasses($indexInfo, [string[]] $typeClasses) {
        foreach ( $typeClass in $typeClasses ) {
            if ( ! $indexInfo.Initialized[$typeClass] ) {
                $typeProvider = $this.typeProviders[$typeClass]
                $indexesForTypeClass = $typeProvider |=> UpdateTypeIndexes @($indexInfo.Index) $typeClasses
                $indexInfo.Initialized[$typeClass] = $true
            }
        }
    }
}
