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

. (import-script TypeIndexEntry)
. (import-script TypeMatch)

enum TypeIndexClass {
    Name
    Property
    NavigationProperty
    Method
}

enum TypeIndexLookupClass {
    Exact
    StartsWith
    Contains
}

ScriptClass TypeIndex {
    $IndexedField = $null
    $index = $null

    function __initialize([TypeIndexClass] $indexedField) {
        $this.indexedField = $indexedField
        $this.index = [System.Collections.Generic.SortedList[String, Object]]::new(([System.StringComparer]::OrdinalIgnoreCase))
    }

    function Add([string] $lookupValue, $typeId, $typeClass) {
        $entry = __FindEntry $lookupValue

        if ( ! $entry ) {
            $entry = new-so TypeIndexEntry $lookupValue
            $this.index.Add($lookupValue, $entry)
        }

        $entry |=> AddTarget $typeId $typeClass
    }

    function Get($key) {
        if ( ! $this.index.ContainsKey($key) ) {
            throw "Key '$key' not found for index '$($this.indexedField)'"
        }

        __FindEntry $key
    }

    function GetLookupValues {
        $this.index.Keys
    }

    function Find($key, $typeClasses) {
        $entry = __FindEntry $key

        if ( $entry ) {
            foreach ( $matchingType in $entry.targets.keys ) {
                $matchedTypeClass = $entry.targets[$matchingType]
                if ( ! $typeClasses -or ( $typeClasses -contains $matchedTypeClass ) ) {
                    new-so TypeMatch $this.indexedField $null $key $matchingType $true $matchedTypeClass @($key)
                }
            }
        }
    }

    function FindStartsWith($searchString, $typeClasses) {
        $matchedValues = $this.index.keys | where { $_.StartsWith($searchString) }

        if ( $matchedValues ) {
            foreach ( $matchingvalue in $matchedValues ) {
                $entry = $this.index[$matchingValue]
                foreach ( $matchingType in $entry.targets.keys ) {
                    $matchedTypeClass = $entry.targets[$matchingType]
                    if ( ! $typeClasses -or ( $typeClasses -contains $matchedTypeClass ) ) {
                        new-so TypeMatch $this.indexedField $null $searchString $matchingType $false $matchedTypeClass $matchedValues
                    }
                }
            }
        }
    }

    function FindContains($searchString, $typeClasses) {
        $normalizedSearchString = $searchString.tolower()

        $matchedValues = $this.index.keys | where { $_.tolower().Contains($normalizedSearchString) }

        if ( $matchedValues ) {
            foreach ( $matchingvalue in $matchedValues ) {
                $entry = $this.index[$matchingValue]
                foreach ( $matchingType in $entry.targets.keys ) {
                    $matchedTypeClass = $entry.targets[$matchingType]
                    if ( ! $typeClasses -or ( $typeClasses -contains $matchedTypeClass ) ) {
                        new-so TypeMatch $this.indexedField $null $searchString $matchingType $false $matchedTypeClass $matchedValues
                    }
                }
            }
        }
    }

    function __FindEntry($key) {
        $this.index[$key]
    }
}
