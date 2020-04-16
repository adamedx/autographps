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

ScriptClass QueryHelper {
    static {
        function ToFilterParameter([HashTable] $propertyFilter, [string] $oDataFilter) {
            if ( $oDataFilter ) {
                $oDataFilter
            } elseif ( $propertyFilter ) {
                $filter = ''
                foreach ( $property in $propertyFilter.keys ) {
                    if ( $filter ) {
                        $filter += ' and '
                    }

                    $propertyValue = $propertyFilter[$property]

                    $valueArgument = if ( $propertyValue -is [string] ) {
                        "'$propertyValue'"
                    } else {
                        $propertyValue
                    }

                    $filter += ( '{0} eq {1}' -f $property, $valueArgument )
                }
                $filter
            }
        }

        function ValidatePropertyProjection($graphContext, $typeInfo, $projection, $propertyTypeToValidate) {
            if ( $projection ) {
                $allowedPropertyTypes = 'Property', 'NavigationProperty'

                $propertyTypes = if ( ! $propertyTypeToValidate ) {
                    $allowedPropertyTypes
                } elseif ( $allowedPropertyTyeps -contains $propertyTypeToValidate ) {
                    $propertyTypeToValidate
                } else {
                    throw "Invalid property type '$propertyTypeToValidate'"
                }

                $typeManager = $::.TypeManager |=> Get $graphContext

                $typeData = $typeManager |=> GetTypeDefinition Entity $typeInfo.FullTypeName

                $properties = foreach ( $propertyType in $propertyTypes ) {
                    $typeManager |=> GetTypeDefinitionTransitiveProperties $typeData $propertyType
                }

                $propertyMap = @{}

                foreach ( $property in $properties ) {
                    $propertyMap.Add($property.name, $property)
                }

                foreach ( $propertyName in $projection ) {
                    if ( ! $propertyMap[$propertyName] ) {
                        throw "The specified property '$propertyName' is not a member of type '$($typeInfo.FullTypeName)'"
                    }
                }
            }
        }
    }
}
