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

ScriptClass RequestHelper {
    static {
        function GraphObjectToWriteRequestObject($graphObject, $excludedProperties, [HashTable] $includedProperties) {
            $filteredObject = @{}

            $responseObject = if ( $::.SegmentHelper |=> IsGraphSegmentType $graphObject ) {
                $graphObject.content
            } else {
                $graphObject
            }

            $properties = $responseObject | get-member -MemberType NoteProperty | where {
                # 1. Remove id field since it can never be put / patch / posted
                # 2. Also remove any odata properties -- these aren't part of the object
                #    and were added as metadata to the response by Graph
                # 3. Remove any excluded properties -- the object may have read-only properties
                #    for instance, so the caller will want to exclude them
                # 4. Remove any null fields -- its not clear that it is valid to specify a field as
                #    null on a write request in general, and most APIs seem to fail with it. Workaround
                #    if null is truly needed is to specify those nulls via the includedProperties parameter
                $_.name -ne 'id' -and ! $_.name.startswith('@') -and ($_.name -notin $excludedProperties) -and ( $responseObject.$($_.name) -ne $null )
            } | select -ExpandProperty name

            foreach ( $property in $properties ) {
                $filteredObject.Add($property, $responseObject.$property)
            }

            if ( $includedProperties ) {
                foreach ( $includedPropertyName in $includedProperties.keys ) {
                    $filteredObject[$includedPropertyName] = $includedProperties[$includedPropertyName]
                }
            }

            $filteredObject
        }
    }
}
