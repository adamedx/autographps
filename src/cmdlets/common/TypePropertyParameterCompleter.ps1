# Copyright 2019, Adam Edwards
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

ScriptClass TypePropertyParameterCompleter {
    enum PropertyType {
        Property
        NavigationProperty
    }

    $PropertyType = $null

    function __initialize($propertyType = 'Property') {
        $this.propertyType = [PropertyType] $propertyType
    }

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $typeClass = $fakeBoundParameters['TypeClass']
        $graphName = $fakeBoundParameters['GraphName']
        $fullyQualified = if ( $fakeBoundParameters['FullyQualifiedTypeName'] ) {
            $fakeBoundParameters.IsPresent
        }
        $typeName = $fakeBoundParameters['TypeName']

        if ( ! $typeName ) {
            return $null
        }

        $targetTypeClass = if ( ! $typeClass -or $typeClass -eq 'Any' ) {
            'Unknown'
        } else {
            $typeClass
        }

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

        if ( $targetContext ) {
            $typeManager = $::.TypeManager |=> Get $targetContext
            $isFullyQualified = $fullyQualified -or ( $typeClass -ne 'Primitive' -and $TypeName.Contains('.') )

            $type = $typeManager |=> FindTypeDefinition $targetTypeClass $typeName $isFullyQualified ($targetTypeClass -ne 'Unknown')
            $typeProperties = if ( $type ) {
                $typeManager |=> GetTypeDefinitionTransitiveProperties $type $this.propertyType
            }

            $typeProperties.name | where { $_.startswith($wordToComplete, [System.StringComparison]::InvariantCultureIgnoreCase) }
        }
    }
}
