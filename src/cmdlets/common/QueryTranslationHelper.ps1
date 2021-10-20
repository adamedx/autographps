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

ScriptClass QueryTranslationHelper {
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
                    } elseif ( $propertyValue -is [boolean] ) {
                        if ( $propertyValue ) {
                            'true'
                        } else {
                            'false'
                        }
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
                } elseif ( $allowedPropertyTypes -contains $propertyTypeToValidate ) {
                    $propertyTypeToValidate
                } else {
                    throw "Invalid property type '$propertyTypeToValidate'"
                }

                $typeManager = $::.TypeManager |=> Get $graphContext

                $properties = GetTypeProperties $graphContext $typeInfo.FullTypeName $propertyTypes

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

        function GetTypeProperties($graphContext, $typeName, $propertyTypes) {
            $typeManager = $::.TypeManager |=> Get $graphContext

            $typeData = $typeManager |=> GetTypeDefinition Entity $typeName

            foreach ( $propertyType in $propertyTypes ) {
                $typeManager |=> GetTypeDefinitionTransitiveProperties $typeData $propertyType
            }
        }

        function GetSimpleMatchFilter($graphContext, $typeName, $simpleMatch) {
            $properties = GetTypeProperties $graphContext $typeName Property

            $orderedMatchProperties = 'displayName', 'name', 'givenName', 'userPrincipalName', 'mail', 'mailNickName', 'title', 'fileName', 'subject'

            $validMatchProperties = @()
            $maxPropertiesToFilter = 2 # Limit this to avoid possibility of the property being unsupported for filtering on a given API

            foreach ( $property in $orderedMatchProperties ) {
                if ( $property -in $properties.name ) {
                    $validMatchProperties += $property
                    if ( $validMatchProperties.length -eq $maxPropertiesToFilter ) {
                        break
                    }
                }
            }

            if ( ! $validMatchProperties ) {
                throw [ArgumentException]::new("Unable to perform a simple match for type '$typeName' because it does not contain one of the following properties: {0}" -f (
                                                   $orderedMatchProperties -join ', '))
            }

            $matchClauses = $validMatchProperties | foreach {
                "startsWith($_, '$simpleMatch')"
            }

            $matchClauses -join ' or '
        }
    }
}
