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

ScriptClass TypeParameterCompleter {
    $explicitTypeClasses = $null
    $unqualified = $false

    function __initialize( $explicitTypeClass = $null, $unqualified = $false ) {
        $this.explicitTypeClasses = $explicitTypeClasses
        $this.unqualified = $unqualified
    }

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $graphName = $fakeBoundParameters['GraphName']
        $fullyQualified = $null

        $typeClass = if ( $this.explicitTypeClasses ) {
            $this.explicitTypeClasses
        } else {
            , $fakeBoundParameters['TypeClass']
            $fullyQualified = if ( $fakeBoundParameters['FullyQualifiedTypeName'] ) {
                $fakeBoundParameters['FullyQualifiedTypeName'].IsPresent
            }
        }

        $targetTypeClasses = if ( ! $typeClass -or $typeClass -eq 'Any' ) {
            , 'Unknown'
        } else {
            $typeClass
        }

        $targetWord = if ( $this.unqualified -or $fullyQualified -or ( $typeClass -eq 'Primitive' ) -or $wordToComplete.Contains('.') ) {
            $wordToComplete
        } else {
            'microsoft.graph.' + $wordToComplete
        }

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

        if ( $targetContext ) {
            $typeNames = $::.TypeManager |=> GetSortedTypeNames $targetTypeClasses $targetContext

            $candidates = if ( $this.unqualified ) {
                $typeNames | foreach { $_ -split '\.' | select -last 1 }
            } else {
                $typeNames
            }

            $::.ParameterCompleter |=> FindMatchesStartingWith $targetWord $candidates
        }
    }
}
