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

ScriptClass TypeTable {
    $types = $null
    $providers = $null
    $orderedClasses = $null

    function __initialize([PSCustomObject][] $providers, [string][] $orderedTypeClasses) {
        $this.types = @{}
        $this.providers = [ordered] @{}
        $this.classes = $orderedTypeClasses

        $providerCount = $providers.length

        for ( $providerIndex = 0; $providerIndex -lt $providers.length; $providerIndex++ ) {
            $this.providers.Add($orderedTypeClasses[$providerIndex], @{Provider=$providers[$providerIndex];Initialized=$false})
        }
    }

    function GetType([string] $typeId, $typeClass) {
        $classes = if ( $typeClass -and $typeClass -ne 'Unknown' ) {
            , $typeClass
        } else {
            $this.providers.keys
        }

        foreach ( $class in $classes ) {
            if ( ! $this.providers[$class].Initialized ) {
                __InitializeTypeClass $class
            }

            $entry = __GetEntry $typeId

            if ( $entry ) {
                $schema = $entry[$class]
                if ( $schema ) {
                    [PSCustomObject] @{TypeId=$typeId;Class=$class;Schema=$schema}
                }
                break
            }
        }
    }

    function __GetEntry($typeId) {
        $this.types[$typeId]
    }

    function __AddEntry($typeId, $entry) {
        if ( __GetEntry $typeId ){
            throw "Entry for type id '$typeId' already exists"
        }

        $this.types.Add($typeId, $entry)
    }

    function __NewEntry($typeId) {
        $entry = @{}

        foreach ( $class in $this.classes ) {
            $entry.Add($class, $null)
        }

        $entry
    }
}
