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

. (import-script ../typesystem/TypeManager)
. (import-script common/TypeHelper)
. (import-script common/TypeParameterCompleter)

enum TypeSearchCriteria {
    Name
    Properties
    Relationships
    Methods
    Members
}

function Find-GraphType {
    [cmdletbinding(positionalbinding=$false)]
    [OutputType('GraphTypeDisplayType')]
    param(
        [parameter(position=0, mandatory=$true)]
        $SearchString,

        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        $TypeClass = 'Any',

        $Namespace,

        $GraphName,

        [TypeSearchCriteria[]] $Criteria
    )
    Enable-ScriptClassVerbosePreference

    if ( $TypeClass -eq 'Primitive' ) {
        throw [ArgumentException]::new("The type class 'Primitive' is not supported for this command")
    }

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    # For each typeclass
    #    match the name
    #    match properties
    #    match navigations
    # For each method type
    #    match the name
    #    match the return type
    #    match the parameters

    $classes = if ( $TypeClass -ne 'Any' ) {
        , $TypeClass
    } else {
        'Enumeration', 'Complex', 'Entity'
    }

    # TypeSearcher::Search($searchTerm, $searchFields, $searchOptions)

    $typeManager = $::.TypeManager |=> Get $targetContext

    $searchResults = $typeManager |=> SearchTypes $SearchString $false $classes

    if ( $searchResults ) {
        foreach ( $result in $searchResults ) {
            Get-GraphType $result.MatchedTypeName -FullyQualifiedTypeName
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphType GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphType Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
