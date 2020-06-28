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

ScriptClass MemberDisplayType {
    $Name = $null
    $TypeId = $null
    $IsCollection = $false
    $MemberType = $null
    $Parameters = $null
    $MethodType = $null

    function __initialize($typeMember) {
        $this.Name = $typeMember.Name
        $this.MemberType = $typeMember.MemberType
        $this.TypeId = $typeMember.TypeId
        $this.IsCollection = $typeMember.IsCollection

        if ( $typeMember.MemberData ) {
            $this.MethodType = $typeMember.MemberData.MethodType

            $parameters = $typeMember.MemberData.Parameters
            if ( $parameters ) {
                $this.Parameters = foreach ( $parameterName in $parameters.keys ) {
                    [PSCustomObject] @{
                        Name = $parameterName
                        TypeId = $parameters[$parameterName].TypeFullName
                        IsCollection = $parameters[$parameterName].IsCollection
                    }
                }
            }

            if ( $typeMember.MemberData.ReturnTypeInfo ) {
                $this.TypeId = $typeMember.MemberData.ReturnTypeInfo.TypeFullName
                $this.IsCollection = $typeMember.MemberData.ReturnTypeInfo.IsCollection
            }
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

        function ToDisplayableMemberList($memberList) {
            foreach ( $member in $memberList ) {
                new-so $this.ClassName $member
            }
        }
    }
}


$::.MemberDisplayType |=> __RegisterDisplayType
