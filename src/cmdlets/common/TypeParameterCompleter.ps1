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

ScriptClass TypeParameterCompleter {
    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $typeClass = $fakeBoundParameters['TypeClass']
        $graphName = $fakeBoundParameters['GraphName']
        $fullyQualified = if ( $fakeBoundParameters['FullyQualifiedTypeName'] ) {
            $fakeBoundParameters.IsPresent
        }

        if ( ! $typeClass ) {
            $typeClass = 'Entity'
        }

        $targetWord = if ( $fullyQualified -or $typeClass -eq 'Primitive' -or $wordToComplete.Contains('.') ) {
            $wordToComplete
        } else {
            'microsoft.graph.' + $wordToComplete
        }

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

        if ( $targetContext ) {
            $typeNames = $::.TypeProvider |=> GetSortedTypeNames $typeClass $targetContext
            $::.ParameterCompleter |=> FindMatchesStartingWith $targetWord $TypeNames
        }
    }
}
