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

. (import-script TypeManager)
. (import-script TypeDefinition)

ScriptClass GraphObjectBuilder {
    $typeManager = $null
    $typeDefinition = $null
    $setDefaultValues = $false
    $maxLevel = 0
    $propertyFilter = $null
    $currentLevel = 0

    function __initialize([PSTypeName('TypeManager')] $typeManager, [PSTypeName('TypeDefinition')] $typeDefinition, $setDefaultValues, $recurse, [string[]] $propertyFilter, [object[]] $valueList) {
        $this.typeManager = $typeManager
        $this.typeDefinition = $typeDefinition
        $this.setDefaultValues = $setDefaultValues -or $valueList

        if ( $propertyFilter ) {
            if ( $valueList -and ( $valueList.length -gt $propertyFilter.length ) ) {
                throw 'Specified list of values has more elements than the specified set of properties'
            }
            $this.propertyFilter = @{}
            for ( $propertyIndex = 0; $propertyIndex -lt $propertyFilter.length; $propertyIndex++ ) {
                $hasValue = $false
                $value = if ( $valueList -and ( $propertyIndex -lt $valueList.length ) ) {
                    $hasValue = $true
                    $valueList[$propertyIndex]
                }

                $this.propertyFilter.Add($propertyFilter[$propertyIndex], @{HasValue=$hasValue;Value=$value})
            }
        }
        $this.maxLevel = if ( $recurse ) {
            $this.scriptclass.MAX_OBJECT_DEPTH
        } else {
            0
        }
    }

    function ToObject {
        $this.currentLevel = 0
        GetMemberValue $null $this.typeDefinition $false $false $null
    }

    function GetMemberValue($memberName, $typeDefinition, $isCollection, $useCustomValue, $customValue) {
        if ( $useCustomValue ) {
            return $customValue
        }

        # For any collection, we simply want to provide an empty array or
        # other defaul representation of the collection
        if ( $isCollection ) {
            if ( $this.setDefaultValues ) {
                if ( $typeDefinition.DefaultCollectionValue ) {
                    , ( . $typeDefinition.DefaultCollectionValue )
                } else {
                    @()
                }
            } else {
                $null
            }
        } else {
            # For non-collections, we want to embed the value directly in
            # the parent object
            if ( $typeDefinition.IsComposite ) {
                NewCompositeValue $typeDefinition
            } else {
                NewScalarValue $typeDefinition
            }
        }
    }

    function NewCompositeValue($typeDefinition) {
        if ( $this.currentLevel -gt $this.scriptclass.MAX_OBJECT_DEPTH ) {
            throw "Object depth maximum of '$($this.scriptclass.MAX_OBJECT_DEPTH)' exceeded"
        }

        if ( $this.currentLevel -gt $this.maxLevel ) {
            return $null
        }

        try {
            $this.currentLevel += 1

            $object = @{}

            if ( $typeDefinition.members ) {
                foreach ( $member in $typeDefinition.members ) {
                    $propertyInfo = if ( $this.propertyFilter ) {
                        $this.propertyFilter[$member.name]
                    }

                    if ( ! $this.propertyFilter -or $propertyInfo ) {
                        $memberTypeDefinition = $this.typeManager |=> FindTypeDefinition Unknown $member.typeId $true

                        if ( ! $memberTypeDefinition ) {
                            throw "Unable to find type '$($member.typeId)' for member $($member.name) of type $($typeDefinition.typeId)"
                        }

                        $hasValue = $propertyInfo -and $propertyInfo.HasValue
                        $customValue = if ( $hasValue ) {
                            $propertyInfo.Value
                        }

                        $value = GetMemberValue $member.Name $memberTypeDefinition $member.isCollection $hasValue $customValue

                        $object.Add($member.Name, $value)
                    }
                }
            }
        } finally {
            $this.currentLevel -= 1
        }

        $object
    }

    function NewScalarValue($typeDefinition) {
        if ( $this.setDefaultValues ) {
            if ( $typeDefinition.DefaultValue -ne $null ) {
                if ( $typeDefinition.DefaultValue -is [ScriptBlock] ) {
                    . $typeDefinition.DefaultValue
                } else {
                    $typeDefinition.DefaultValue
                }
            }
        } else {
            $null
        }
    }

    static {
        const MAX_OBJECT_DEPTH 64
        $maxLevel = 0
    }
}

