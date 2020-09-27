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

ScriptClass MemberParameterCompleter {
    $typeNameParameter = $null
    $memberTypeParameter = $null

    function __initialize( $typeNameParameter, $memberTypeParameter ) {
        $this.typeNameParameter = $typeNameParameter
        $this.memberTypeParameter = $memberTypeParameter
    }

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $graphName = $fakeBoundParameters['GraphName']
        $typeName = $fakeBoundParameters[$this.typeNameParameter]
        $memberType = $fakeBoundParameters[$this.memberTypeParameter]

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $graphName

        $memberFilter = '{0}*' -f $wordToComplete

        $members = $::.TypeMemberFinder |=> FindMembersByTypeName $targetContext $typeName $memberType $null $memberFilter $null $true

        if ( $members ) {
            $members | select-object -expandproperty Name
        }
    }
}
