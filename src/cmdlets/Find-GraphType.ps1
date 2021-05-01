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
. (import-script common/TypeSearchResultDisplayType)
. (import-script common/TypeParameterCompleter)

enum TypeSearchCriterion {
    Name
    Property
    Relationship
    Method
    Member
}

function Find-GraphType {
    [cmdletbinding(positionalbinding=$false)]
    [OutputType('GraphTypeDisplayType')]
    param(
        [parameter(position=0, mandatory=$true)]
        $SearchString,

        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        $TypeClass = 'Entity',

        $Namespace,

        $GraphName,

        [TypeSearchCriterion[]] $Criteria = @('Name'),

        [parameter(position=1)]
        [ValidateSet('Exact', 'StartsWith', 'Contain')]
        $MatchType = 'Contains'
    )
    Enable-ScriptClassVerbosePreference

    if ( $TypeClass -contains 'Primitive' ) {
        throw [ArgumentException]::new("The type class 'Primitive' is not supported for this command")
    }

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    # For each typeclass
    #    match the name
    #    match properties
    #    match navigations
    # For each method type
    #    match the name
    #    match the return type -- TODO
    #    match the parameters -- TODO

    $classes = if ( $TypeClass -notcontains 'Any' ) {
        $TypeClass
    } else {
        'Entity', 'Complex', 'Enumeration'
    }

    $typeManager = $::.TypeManager |=> Get $targetContext

    $targetCriteria = [ordered] @{}

    foreach ( $criterion in $Criteria ) {
        if ( $criterion -eq 'Member' ) {
            'Property', 'NavigationProperty', 'Method' | foreach {
                $targetCriteria[$_] = $true
            }
        } elseif ( $criterion -eq 'Relationship' ) {
            $targetCriteria['NavigationProperty'] = $true
        } else {
            $targetCriteria[$criterion] = $true
        }
    }

    $searchResults = $typeManager |=> SearchTypes $SearchString $targetCriteria.Keys $classes $MatchType |
      sort-object Score -descending

    if ( $searchResults ) {
        foreach ( $result in $searchResults ) {
            new-so TypeSearchResultDisplayType $result $targetContext.Name
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphType GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphType Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
