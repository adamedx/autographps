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

. (import-script TypeUriHelper)
. (import-script TypeParameterCompleter)
. (import-script TypePropertyParameterCompleter)

ScriptClass TypeUriParameterCompleter {
    $typeCompleter = $null
    $typeParameterName = $null

    function __initialize($parameterType, $unqualified = $false, $propertyType = 'Property', $typeParameterName) {
        $this.typeParameterName = if ( $typeParameterName ) {
            $typeParameterName
        } else {
            'TypeName'
        }

        $this.typeCompleter = if ( $parameterType -eq 'TypeName' ) {
            new-so TypeParameterCompleter Entity $unqualified
        } elseif ( $parameterType -eq 'Property' ) {
            new-so TypePropertyParameterCompleter $propertyType
        } else {
            throw [ArgumentException]::new("The specified parameter type '$parameterType' must be one of 'TypeName' or 'Property'")
        }
    }

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $uriParam = $fakeBoundParameters['Uri']
        $graphNameParam = $fakeBoundParameters['GraphName']
        $graphObjectParam = $fakeBoundParameters['GraphObject']
        $typeNameParam = $fakeBoundParameters[$this.typeParameterName]

        $typeName = if ( $typeNameParam ) {
            $typeNameParam
        } else {
            $targetUri = if ( $uriParam ) {
                $uriParam
            } elseif ( $graphObjectParam ) {
                $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphNameParam
                if ( $targetContext ) {
                    $::.TypeUriHelper |=> GetUriFromDecoratedObject $targetContext $graphObjectParam
                }
            }

            if ( $targetUri ) {
                $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphNameParam
                $::.TypeUriHelper |=> TypeFromUri $targetUri $targetContext | select -expandproperty FullTypeName
            }
        }

        if ( ! $typeName ) {
            return
        }

        $forwardedBoundParams = @{
            TypeName = $typeName
            GraphName = $graphNameParam
            TypeClass = 'Entity'
        }

        $this.typeCompleter |=> CompleteCommandParameter $commandName $parameterName $wordToComplete $commandAst $forwardedBoundParams
    }
}
