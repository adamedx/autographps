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

. (import-script ../../typesystem/TypeManager)
. (import-script TypeHelper)

ScriptClass TypeMemberFinder {
    static {
        function FindMembersByTypeName($context, $fullyQualifiedTypeName, $memberType, $memberName, $memberFilter, $badTypeMessage, [bool] $literalFilter) {
            $typeManager = $::.TypeManager |=> Get $context

            $type = $typeManager |=> FindTypeDefinition Unknown $fullyQualifiedTypeName $true $true

            if ( $type ) {
                FindMembersByType $typeManager $type $memberType $memberName $memberFilter
            } elseif ( $badTypeMessage ) {
                throw $badTypeMessage
            }
        }

        function FindMembersByType($typeManager, $type, $memberType, $memberName, $memberFilter) {
            $fieldMap = [ordered] @{
                Property = 'Property'
                Relationship = 'NavigationProperty'
                Method = 'Method'
            }

            $orderedMemberFields = if ( $memberType ) {
                , $fieldMap[$MemberType]
            } else {
                $fieldMap.values
            }

            foreach ( $memberField in $orderedMemberFields ) {
                $allMembers = $typeManager |=> GetTypeDefinitionTransitiveProperties $type $memberfield

                $matchingMembers = $allMembers | where {
                    if ( $memberName ) {
                        $_.Name -in $memberName
                    } elseif ( $memberFilter ) {
                        $targetFilter = if ( $literalFilter ) {
                            $memberFilter
                        } else {
                            "*$($memberFilter)*"
                        }
                        $_.Name -like $targetFilter
                    } else {
                        $true
                    }
                }

                $matchingMembers | sort-object name | foreach {
                    new-so MemberDisplayType $_ $type.TypeId
                }
            }
        }
    }
}
