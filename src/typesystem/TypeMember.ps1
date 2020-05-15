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

ScriptClass TypeMember {
    $Name = $null
    $TypeId = $null
    $IsCollection = $null
    $MemberType = $null

    function __initialize($name, $typeId, $isCollection, $memberType) {
        $this.Name = $name
        $this.TypeId = $typeId
        $this.IsCollection = $isCollection
        $this.MemberType = if ( $memberType -eq $null -or $MemberType -eq 'Property' ) {
            'Property'
        } elseif ( $memberType -eq 'NavigationProperty' ) {
            'Relationship'
        } else {
            throw [ArgumentException]::new("Invalid member type '$memberType' specified: member type must be one of 'Property' or 'NavigationProperty'")
        }
    }

    static {
        function __RegisterDisplayType {
            $displayTypeName = $this.ClassName

            $displayProperties = @('Name', 'MemberType', 'TypeId', 'IsCollection')

            remove-typedata -typename $displayTypeName -erroraction ignore

            $displayTypeArguments = @{
                TypeName = $displayTypeName
                DefaultDisplayPropertySet = $displayProperties
            }

            Update-TypeData -force @displayTypeArguments
        }
    }
}


$::.TypeMember |=> __RegisterDisplayType
