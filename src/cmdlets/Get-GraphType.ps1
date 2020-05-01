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

function Get-GraphType {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='optionallyqualified')]
    [OutputType('GraphTypeDisplayType')]
    param(
        [parameter(position=0, parametersetname='optionallyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='optionallyqualifiedmembersonly', mandatory=$true)]
        [parameter(position=0, parametersetname='fullyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='fullyqualifiedmembersonly', mandatory=$true)]
        [Alias('Name')]
        $TypeName,

        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        [Alias('Class')]
        $TypeClass = 'Any',

        [parameter(parametersetname='optionallyqualified')]
        [parameter(parametersetname='optionallyqualifiedmembersonly')]
        $Namespace,

        $GraphName,

        [parameter(parametersetname='fullyqualified', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedmembersonly', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [parameter(parametersetname='optionallyqualifiedmembersonly', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedmembersonly', mandatory=$true)]
        [switch] $TransitiveMembers,

        [parameter(position=1, parametersetname='optionallyqualifiedmembersonly')]
        [parameter(position=1, parametersetname='fullyqualifiedmembersonly')]
        [string] $MemberFilter,

        [parameter(parametersetname='list', mandatory=$true)]
        [switch] $ListNames
    )

    Enable-ScriptClassVerbosePreference

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    if ( ! $ListNames.IsPresent ) {
        $remappedTypeClass = if ( $TypeClass -ne 'Any' ) {
            $TypeClass
        } else {
            'Unknown'
        }

        $typeManager = $::.TypeManager |=> Get $targetContext

        $isFullyQualified = $FullyQualifiedTypeName.IsPresent -or ( $TypeClass -ne 'Primitive' -and $TypeName.Contains('.') )

        $type = $typeManager |=> FindTypeDefinition $remappedTypeClass $TypeName $isFullyQualified ( $TypeClass -ne 'Any' )

        if ( ! $type ) {
            throw "The specified type '$TypeName' of type class '$TypeClass' was not found in graph '$($targetContext.name)'"
        }

        $result = $::.TypeHelper |=> ToPublic $type

        if ( ! $TransitiveMembers.IsPresent ) {
            $result
        } else {
            if ( ! $MemberFilter ) {
                $result.Properties
                $result.NavigationProperties
            } else {
                $result.Properties | where { $_.Name -like "*$($MemberFilter)*" }
                $result.NavigationProperties | where { $_.Name -like "*$($MemberFilter)*" }
            }
        }
    } else {
        $sortTypeClass = if ( $TypeClass -ne 'Any' ) {
            $TypeClass
        } else {
            'Entity'
        }
        $::.TypeManager |=> GetSortedTypeNames $sortTypeClass $targetContext
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphType TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphType GraphName (new-so GraphParameterCompleter)
