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

    function __initialize([PSTypeName('TypeManager')] $typeManager, [PSTypeName('TypeDefinition')] $typeDefinition, $setDefaultValues, $recurse, [string[]] $propertyFilter, [object[]] $valueList, [HashTable[]] $propertyList ) {
        $this.typeManager = $typeManager
        $this.typeDefinition = $typeDefinition
        $this.setDefaultValues = $setDefaultValues -or $valueList -or ! $typeDefinition.IsComposite

        $values = $valueList
        $properties = $propertyFilter

        if ( $propertyList ) {
            $values = @()
            $properties = @()

            foreach ( $table in $propertyList ) {
                foreach ( $propertyName in $table.keys ) {
                    $properties += $propertyName
                    $values += $table[$propertyName]
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

        try {
            $this.currentLevel += 1

            $object = @{}

            if ( $typeDefinition.properties ) {
                foreach ( $property in $typeDefinition.properties ) {
                    $propertyInfo = if ( $this.propertyFilter ) {
                        $this.propertyFilter[$property.name]
                    }

                    if ( ! $this.propertyFilter -or $propertyInfo ) {
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

