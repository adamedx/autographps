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
. (import-script MethodNameParameterCompleter)
. (import-script MethodParameterParameterCompleter)

ScriptClass MethodUriParameterCompleter {
    $completer = $null
    $parameterToComplete = $null

    function __initialize($parameterType) {
        $this.completer = if ( $parameterType -eq 'MethodName' ) {
            new-so MethodNameParameterCompleter
        } elseif ( $parameterType -eq 'ParameterName' ) {
            new-so MethodParameterParameterCompleter
        } else {
            throw [ArgumentException]::new("The specified parameter type '$parameterType' must be one of 'MethodName' or 'ParameterName'")
        }
    }

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $uriParam = $fakeBoundParameters['Uri']
        $graphNameParam = $fakeBoundParameters['GraphName']
        $methodNameParam = $fakeBoundParameters['MethodName']
        $typeNameParam = $fakeBoundParameters['TypeName']
        $graphObjectParam = $fakeBoundParameters['GraphItem']
        $isFullyQualified = if ( $fakeBoundParameters['FullyQualifiedTypeName'] ) {
            $fakeBoundParameters['FullyQualifiedTypeName'].IsPresent
        } else {
            $false
        }

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphNameParam

        $typeName = if ( $typeNameParam ) {
            $typeNameParam
        } else {
            $isFullyQualified = $true
            $targetUri = if ( $uriParam ) {
                $uriParam
            } elseif ( $graphObjectParam ) {
                if ( $targetContext ) {
                    $::.TypeUriHelper |=> GetUriFromDecoratedObject $targetContext $graphObjectParam
                }
            } else {
                '.'
            }

            if ( $targetUri ) {
                $::.TypeUriHelper |=> TypeFromUri $targetUri $targetContext | select -expandproperty FullTypeName
            }
        }

        if ( ! $typeName ) {
            return
        }

        $forwardedBoundParams = @{
            TypeName = $typeName
            MethodName = $methodNameParam
            GraphName = $graphNameParam
            Uri = $uriParam
            FullyQualifiedTypeName = ([System.Management.Automation.SwitchParameter]::new($isFullyQualified))
        }

        $this.completer |=> CompleteCommandParameter $commandName $parameterName $wordToComplete $commandAst $forwardedBoundParams
    }
}
