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
    $skipPropertyCheck = $false
    $maxLevel = 0
    $propertyFilter = $null
    $currentLevel = 0

    function __initialize([PSTypeName('TypeManager')] $typeManager, [PSTypeName('TypeDefinition')] $typeDefinition, $setDefaultValues, $recurse, [string[]] $propertyFilter, [object[]] $valueList, [HashTable[]] $propertyList, [bool] $skipPropertyCheck ) {
        $this.typeManager = $typeManager
        $this.typeDefinition = $typeDefinition
        $this.setDefaultValues = $setDefaultValues -or $valueList -or ! $typeDefinition.IsComposite
        $this.skipPropertyCheck = $skipPropertyCheck

        $values = $valueList
        $properties = $propertyFilter

        if ( $propertyList ) {
            $values = @()
            $properties = @()

            foreach ( $table in $propertyList ) {
                foreach ( $propertyName in $table.keys ) {
                    $properties += $propertyName

                    # The rather awkward way of adding a value to this array is necessitated by the behavior described
                    # in a "WARNING" elsewhere in this file: if you use the += operator to add the value and the value
                    # is an array with one element, it adds the element, rather than the actual array value. This is absolutely
                    # not the desired behavior in this context -- the types used by the caller are to be used literally in
                    # order to deterministically serialize into JSON that meets the API contract where the object being built
                    # by this instance will likely be used.
                    $values += $null # Make space in the array first
                    $values[$values.length -1] = $table[$propertyName] # Then add the element -- a simple assignment preserves the type
                }
            }
        }

        if ( $properties ) {
            if ( $valueList -and ( $valueList.length -gt $properties.length ) ) {
                throw 'Specified list of values has more elements than the specified set of properties'
            }
            $this.propertyFilter = @{}
            for ( $propertyIndex = 0; $propertyIndex -lt $properties.length; $propertyIndex++ ) {
                $hasValue = $false
                # WARNING: Be very careful in how the value supplied by the user is handled. PowerShell
                # has a very strange behavior where a function cannot return a single element array -- the
                # array gets converted to just the single element! The conditional 'if' statement shares
                # this behavior. There are various workarounds, though the simplest to understand is to
                # avoid returning arrays from a function or assigning from an if, try, or other statement.
                # See https://blog.tyang.org/2011/02/24/powershell-functions-do-not-return-single-element-arrays/.
                # Ultimately unit tests are the only defense against regressions in this area.
                $value = $null
                if ( $values -and ( $propertyIndex -lt $values.length ) ) {
                    $hasValue = $true
                    $value = $values[$propertyIndex]
                }

                $this.propertyFilter.Add($properties[$propertyIndex], @{HasValue=$hasValue;Value=$value})
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
        GetPropertyValue $this.typeDefinition $false $false $null
    }

    function GetPropertyValue($typeDefinition, $isCollection, $useCustomValue, $customValue) {
        if ( $useCustomValue ) {
            if ( $customValue -and $customValue.GetType().IsArray -and ( $customValue.length -eq 1 ) ) {
                return , $customValue
            } else {
                return $customValue
            }
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

        $object = @{}
        $usedProperties = @{}
        $unusedPropertyCount = 0

        try {
            $this.currentLevel += 1

            if ( $this.PropertyFilter -and ( $this.currentLevel -eq 1 ) ) {
                foreach ( $referencedProperty in $this.PropertyFilter.keys ) {
                    $usedProperties.Add($referencedProperty, $false)
                    $unusedPropertyCount++
                }
            }

            $typeProperties = $this.typeManager |=> GetTypeDefinitionTransitiveProperties $typeDefinition

            foreach ( $property in $typeProperties ) {
                $propertyInfo = if ( ( $this.currentLevel -eq 1 ) -and $this.propertyFilter ) {
                    if ( $usedProperties.ContainsKey($property.name) ) {
                        $usedProperties[$property.name] = $true
                        $unusedPropertyCount--
                    }
                    $this.propertyFilter[$property.name]
                }

                if ( ! ( ( $this.currentLevel -eq 1 ) -and $this.propertyFilter ) -or $propertyInfo ) {
                    if ( ( $this.currentLevel -eq 1 ) -and $typeDefinition.Class -eq 'Entity' -and $property.name -eq 'id' ) {
                        continue
                    }

                    $propertyTypeDefinition = $this.typeManager |=> FindTypeDefinition Unknown $property.typeId $true

                    if ( ! $propertyTypeDefinition ) {
                        throw "Unable to find type '$($property.typeId)' for property $($property.name) of type $($typeDefinition.typeId)"
                    }

                    $hasValue = $propertyInfo -and $propertyInfo.HasValue

                    $customValue = $null
                    if ( $hasValue ) {
                        $customValue = $propertyInfo.Value
                    }

                    $value = GetPropertyValue $propertyTypeDefinition $property.isCollection $hasValue $customValue

                    $object.Add($property.Name, $value)
                }
            }
        } finally {
            $this.currentLevel -= 1
        }

        if ( ! $this.skipPropertyCheck -and $unusedPropertyCount -ne 0 ) {
            $unusedProperties = ( $usedProperties.keys | where { ! $usedProperties[$_] } ) -join ', '
            throw "One or more specified properties is not a valid property for type '$($TypeDefinition.name)': '$unusedProperties'"
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

