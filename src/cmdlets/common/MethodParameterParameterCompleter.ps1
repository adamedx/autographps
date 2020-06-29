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

ScriptClass MethodParameterParameterCompleter {

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $graphName = $fakeBoundParameters['GraphName']
        $fullyQualified = if ( $fakeBoundParameters['FullyQualifiedTypeName'] ) {
            $fakeBoundParameters['FullyQualifiedTypeName'].IsPresent
        }
        $typeName = $fakeBoundParameters['TypeName']
        $methodName = $fakeBoundParameters['MethodName']
        $uriParam = $fakeBoundParameters['Uri']

        if ( ( ! $typeName -and ! $methodName ) -and ! $uriParam ) {
            return $null
        }

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

        if ( $targetContext ) {
            $typeManager = $::.TypeManager |=> Get $targetContext
            $targetTypeName = if ( $uriParam ) {
                $fullyQualified = $true
                $graphNameArgument = if ( $graphName ) { @{GraphName=$graphName} } else { @{} }
                $uriInfo = Get-GraphUriInfo $uriParam @graphNameArgument -erroraction stop
                if ( $uriInfo ) {
                    if ( $uriInfo.Class -in 'Action', 'Function' ) {
                        $methodName = $uriInfo.Name
                        $uriParentInfo = Get-GraphUriInfo $uriInfo.ParentPath @graphNameArgument -erroraction stop
                        $uriParentInfo.FullTypeName
                    } elseif ( $methodName ) {
                        $uriInfo.FullTypeName
                    }
                }
            } elseif ( $typeName ) {
                $typeName
            }

            $type = if ( $targetTypeName ) {
                $typeManager |=> FindTypeDefinition Unknown $targetTypeName $fullyQualified $false
            }

            $parameterNames = if ( $type ) {
                $method = $type.methods | where name -eq $methodName
                if ( $method ) {
                    $method.Parameters.Name
                }
            }

            if ( $parameterNames ) {
                $parameterNames | where { $_.startswith($wordToComplete, [System.StringComparison]::InvariantCultureIgnoreCase) }
            }
        }
    }
}
