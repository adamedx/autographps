# Copyright 2017, Adam Edwards
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

ScriptClass GraphResponse {
    $restResponse = strict-val [PSCustomObject]
    $entities = $null
    $odataContext = strict-val [Uri]
    $odataNextLink = strict-val [Uri]
    $metadata = strict-val [HashTable] @{}

    function __initialize ( $restResponse ) {
        $this.restResponse = $restResponse

        $normalizedResponse = $this |=> GetNormalizedResponse $restResponse

        $this.metadata = $normalizedResponse.metadata
        if ( $normalizedResponse.entities -isnot [Object[]] ) {
            $this.entities = @($normalizedResponse.entities)
        } else {
            $this.entities = $normalizedResponse.entities
        }

        $this.odataContext = $this.metadata['@odata.context']
        $this.odataNextLink = $this.metadata['@odata.nextLink']
    }

    function GetNormalizedResponse($restResponse) {
        $metadata = @{}
        $responseData = NormalizePSObject $restResponse 0 1

        $valueData = $null

        $responseData.keys | foreach {
            if ( $_ -eq 'value' ) {
                $valueData = $responseData[$_]
            } elseif ($_.startswith('@')) {
                try {
                    $metadata[$_] = $responseData[$_]
                } catch {
                }
            }
        }

        $entityData = if ( $valueData -ne $null -and $metadata.keys.count -gt 0 ) {
            $valueData
        } else {
            $responseData
        }

        $normalizedEntities = Normalize $entityData 0 1

        @{
            entities=$normalizedEntities
            metadata=$metadata
        }
    }

    function Normalize($object, $depth = 0, $maximumDepth = 1) {
        if ($maximumDepth -eq $null) {
            throw "Invalid maximum depth"
        }

        if ( $maximumDepth -gt 0 -and $depth -ge $maximumDepth) {
            return $object
        }

        $result = if ( $object -eq $null ) {
            $null
        } elseif ( $object -is [Object[]] ) {
            NormalizeArray $object $depth $maximumDepth
        } elseif ( $object -is [HashTable] ) {
            $object
        } elseif ( $object.gettype().fullname -eq 'System.Management.Automation.PSCustomObject' ) {
            NormalizePSObject $object $depth $maximumDepth
        } else {
            $object
        }

        $result
    }

    function NormalizeArray($array, $depth, $maximumDepth) {
        # No point in normalizing individual items if the call is
        # just going to return the item -- we will have simply copied
        # everything to a new array -- better to just return the array.
        # Array normalization doesn't transform the type of the array,
        # it just transforms the contents
        if ( $maximumDepth -eq ($depth + 1)) {
            return $array
        }

        $result = @()
        $array | foreach {
            $result += (Normalize $_ ($depth + 1) $maximumDepth)
        }
        $result
    }

    function NormalizePSObject([PSObject] $psobject, $depth, $maximumDepth) {
        $result = @{}
        $psobject | gm -membertype noteproperty | select -expandproperty name | foreach {
            $memberName = $_
            $memberValue = $psobject | select -expandproperty $memberName
            $normalizedValue = (Normalize $memberValue ($depth + 1) $maximumDepth)
            $result[$memberName] = $normalizedValue
        }
        $result
    }
}
