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
    $maxLevel = $null
    $currentLevel = 0

    function __initialize([PSTypeName('TypeManager')] $typeManager, [PSTypeName('TypeDefinition')] $typeDefinition, $setDefaultValues, $maxLevel) {
        $this.typeManager = $typeManager
        $this.typeDefinition = $typeDefinition
        $this.setDefaultValues = $setDefaultValues
        $this.maxLevel = if ( ! $maxLevel ) {
            $this.scriptlass.MAX_OBJECT_DEPTH
        } else {
            $maxLevel
        }
    }

    function ToObject {
        $this.currentLevel = 0
        GetMemberValue $this.typeDefinition $false
    }

    function GetMemberValue($typeDefinition, $isCollection) {
        $this.currentLevel += 1

        if ( $this.currentLevel -gt $this.scriptclass.MAX_OBJECT_DEPTH ) {
            throw "Object depth maximum of '$($this.scriptclass.MAX_OBJECT_DEPTH)' exceeded"
        }

        if ( $this.currentLevel -gt $this.maxLevel ) {
            return $null
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

        $this.currentLevel -= 1
    }

    function NewCompositeValue($typeDefinition) {
        $this.scriptclass.maxLevel = [Math]::Max($this.scriptclass.maxLevel, $this.currentLevel)

        $object = @{}

        if ( $typeDefinition.members ) {
            foreach ( $member in $typeDefinition.members ) {
                $memberTypeDefinition = $this.typeManager |=> FindTypeDefinition Unknown $member.typeId $true

                if ( ! $memberTypeDefinition ) {
                    throw "Unable to find type '$($member.typeId)' for member $($member.name) of type $($typeDefinition.typeId)"
                }

                $value = GetMemberValue $memberTypeDefinition $member.isCollection

                $object.Add($member.Name, $value)
            }
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

