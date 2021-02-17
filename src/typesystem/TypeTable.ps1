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
    # The idea of this class allows for fast lookup of types based on specific
    # fields in the metadata of the types, including the names, properties,
    # and methods of the types. The quick lookup us implemented by
    # indexing these fields.

    $types = $null
    $indexes = $null
    $orderedClasses = $null

    function __initialize([PSCustomObject[]] $typeIndexes, [string[]] $orderedTypeClasses, [string[]] $sortedTypeNames, $typeFinder) {
        $this.types = [System.Collections.Generic.SortedDictionary[string, object]]::new(([System.StringComparer]::OrdinalIgnoreCase))
        $this.indexes = @{}

        # Create empty indexes for each desired field
        'Name', 'Property', 'NavigationProperty', 'Method' | foreach {
            $index = new-so TypeIndex $_
            $this.indexes.Add($_, $index)
        }

        # Now initialize each of the indexes by merging the different indexes
        # that share the same field
        foreach ( $index in $typeIndexes ) {
            $lookupValues = $index |=> GetLookupValues
            foreach ( $lookupValue in $lookupValues ) {
                $entry = $index |=> Get $lookupValue
                foreach ( $typeId in $entry.targets.keys ) {
                    if ( ! $this.indexes[$index.IndexedField.tostring()] ) {
                    }
                    $this.indexes[$index.IndexedField.tostring()] |=> Add $lookupValue $typeId $entry.targets[$typeId]
                }
            }
        }

        $this.orderedClasses = $orderedTypeClasses

        foreach ( $typeId in $sortedTypeNames ) {
            $entry = __NewEntry $typeId
            __AddEntry $entry
        }
    }

    function GetTypeInfo([string] $typeId, $typeClass) {
        $classes = if ( $typeClass -and $typeClass -ne 'Unknown' ) {
            , $typeClass
        } elseif ( $typeClass -eq 'Primitive' )  {
            throw "Type lookups for the 'Primitive' type class are not supported"
        } else {
            $this.providers.keys
        }

        foreach ( $class in $classes ) {
            if ( ! $this.providers[$class].Initialized ) {
                __InitializeTypeClass $class
            }

            $entry = __GetEntry $typeId

            if ( $entry ) {
                $schema = if ( $entry[$typeId] ) {
                    $entry[$typeId]
                } else {
                    $definition = $this.providers[$typeClass] |=> GetTypeDefinition $typeClass $typeId
                }
                $schema = $entry[$class]
                if ( $schema ) {
                    [PSCustomObject] @{TypeId=$typeId;Class=$class;Schema=$schema}
                }
                break
            }
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

        $targetClasses = if ( $classes ) {
            $classes | where { $_ -ne 'Unknown' }
        } else {
            'Entity', 'Complex'
        }

        $this.indexes[$indexClass.tostring()] |=> $searchMethod $lookupValue $targetClasses
    }

    function GetTypeIndex([TypeIndexClass] $indexClass) {
        $this.indexes[$indexClass.tostring()]
    }

    function AddType($typeId, $class, $schema) {
        $entry = __NewEntry $typeId $class $schema
        __AddEntry $typeId $entry
    }

    function __GetEntry($typeId) {
        $this.types[$typeId]
    }

    function __AddEntry($entry) {
        if ( __GetEntry $entry.TypeId ){
            throw "Entry for type id '$($entry.TypeId)' already exists"
        }

        $this.types.Add($entry.TypeId, $entry)
    }

    function __NewEntry($typeId) {
        @{TypeId=$typeId;Class=$null;Schema=$null}
    }
}

function __GetTable {
    $context = (get-graph).details
    $typeManager = $::.TypeManager |=> Get $context
    $global:mycon = $context
    $global:myman = $typeManager
    $sortedTypeNames = $::.TypeManager |=> GetSortedTypeNames Entity, Complex, Enumeration $context

    $scalarProvider = $typeManager |=> __GetTypeProvider Enumeration
    $compositeProvider = $typeManager |=> __GetTypeProvider Complex
    $typeIndexes = @()

    $global:myprov = $scalarProvider
    $indices = $scalarProvider |=> GetTypeIndexes Name, Property, NavigationProperty, Method
    $compositeIndices = $compositeProvider |=> GetTypeIndexes Name, Property, NavigationProperty, Method
#    $typeFinder = new-so TypeFinder $typeManager

    $typeIndexes += $indices
    $typeIndexes += $compositeIndices

    $global:lasttable = new-so TypeTable $typeIndexes Entity, Complex, Enumeration $sortedTypeNames
    $global:lasttable
}

