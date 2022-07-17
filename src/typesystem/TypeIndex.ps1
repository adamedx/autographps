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
    $typeClassAggregates = $null

    function __initialize([TypeIndexClass] $indexedField) {
        $this.indexedField = $indexedField
        # Note on using keyed collections -- see this PowerShell defect: https://github.com/PowerShell/PowerShell/issues/7758. This is due to PowerShell
        # magical syntactic sugar applied to collections -- if you try to access an instance property of a collection type, PowerShell first
        # tries to find an item with that key name in the collection (presumably only if the collection has string keys)! Specifically this means
        # that if you attempt to access the `Keys` property of a collection to enumerate its keys, it will work as expected *unless* you add a
        # key to the collection that is itself the value string 'Keys'. In that case, you'll get the value associated with that key in the collection rather than
        # the actual Keys property of the collection object. We hit an issue in this codebase for this specific keyed collection when a property was
        # added to an entity in the beta API version called 'keys.' :( The workaround: use the 'get_Keys()' method instead of the 'keys' property.
        # This extends to any other properties of the collection as well such as Count, Length, Values. This is truly a wild problem and extremely
        # unfortunate design choice to prioritize questionable syntactic usability over predictability. In the case for this object, this was encountered
        # as a runtime defect after years of the code running just fine (the Graph API schema change added the property that exposed the flaw).
        #
        # So call to action: use get_xxxx() everywhere for keyed collections (especially if the key is a string!) in place of any properties of the collection.
        $this.index = [System.Collections.Generic.SortedList[String, Object]]::new(([System.StringComparer]::OrdinalIgnoreCase))
        $this.typeClassAggregates = @{
            Entity = 0
            Complex = 0
            Enumeration = 0
        }
    }

    function Add([string] $lookupValue, $typeId, $typeClass) {
        $entry = __FindEntry $lookupValue

        if ( ! $entry ) {
            $entry = new-so TypeIndexEntry $lookupValue
            $this.index.Add($lookupValue, $entry)
        }

        $entry.AddTarget($typeId, $typeClass)

        if ( $this.typeClassAggregates.ContainsKey($typeClass.tostring()) ) {
            $this.typeClassAggregates[$typeClass.tostring()] += 1
        }
    }

    function Get($key) {
        if ( ! $this.index.ContainsKey($key) ) {
            throw "Key '$key' not found for index '$($this.indexedField)'"
        }

        __FindEntry $key
    }

    function GetLookupValues {
        $this.index.get_Keys()
    }

    function Find($key, $typeClasses) {
        $entry = __FindEntry $key

        if ( $entry ) {
            foreach ( $matchingType in $entry.targets.get_Keys() ) {
                $matchedTypeClass = $entry.targets[$matchingType]
                if ( ! $typeClasses -or ( $typeClasses -contains $matchedTypeClass ) ) {
                    new-so TypeMatch $this.indexedField $key $matchingType $matchedTypeClass @($key)
                }
            }
        }
    }

    function FindStartsWith($searchString, $typeClasses) {
        $normalizedSearchString = $searchString.tolower()

        $matchedValues = $this.index.get_Keys() | where { $_.tolower().StartsWith($normalizedSearchString) }

        if ( $matchedValues ) {
            foreach ( $matchingvalue in $matchedValues ) {
                $entry = $this.index[$matchingValue]
                foreach ( $matchingType in $entry.targets.get_Keys() ) {
                    $matchedTypeClass = $entry.targets[$matchingType]
                    if ( ! $typeClasses -or ( $typeClasses -contains $matchedTypeClass ) ) {
                        new-so TypeMatch $this.indexedField $searchString $matchingType $matchedTypeClass $matchedValues
                    }
                }
            }
        }
    }

    function FindContains($searchString, $typeClasses) {
        $normalizedSearchString = $searchString.tolower()

        $matchedValues = $this.index.get_keys() | where { $_.tolower().Contains($normalizedSearchString) }

        if ( $matchedValues ) {
            foreach ( $matchingvalue in $matchedValues ) {
                $entry = $this.index[$matchingValue]
                foreach ( $matchingType in $entry.targets.get_keys() ) {
                    $matchedTypeClass = $entry.targets[$matchingType]
                    if ( ! $typeClasses -or ( $typeClasses -contains $matchedTypeClass ) ) {
                        new-so TypeMatch $this.indexedField $searchString $matchingType $matchedTypeClass @($matchingValue)
                    }
                }
            }
        }
    }

    function GetStatistics {
        [PSCustomObject] @{
            EntityCount = $this.typeClassAggregates['Entity']
            ComplexCount = $this.typeClassAggregates['Complex']
            EnumerationCount = $this.typeClassAggregates['Enumeration']
        }
    }

    function __FindEntry($key) {
        $this.index[$key]
    }
}
