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

        [parameter(parametersetname='optionallyqualified')]
        [parameter(parametersetname='optionallyqualifiedmembersonly')]
        [parameter(parametersetname='fullyqualified')]
        [parameter(parametersetname='fullyqualifiedmembersonly')]
        [parameter(parametersetname='list')]
        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        [Alias('Class')]
        $TypeClass = 'Any',

        [parameter(parametersetname='optionallyqualified')]
        [parameter(parametersetname='optionallyqualifiedmembersonly')]
        $Namespace,

        [parameter(parametersetname='uri', mandatory=$true)]
        [parameter(parametersetname='urimembersonly', mandatory=$true)]
        $Uri,

        $GraphName,

        [parameter(parametersetname='fullyqualified', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedmembersonly', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [parameter(parametersetname='optionallyqualifiedmembersonly', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedmembersonly', mandatory=$true)]
        [parameter(parametersetname='urimembersonly', mandatory=$true)]
        [switch] $TransitiveMembers,

        [parameter(position=1, parametersetname='optionallyqualifiedmembersonly')]
        [parameter(position=1, parametersetname='fullyqualifiedmembersonly')]
        [parameter(parametersetname='urimembersonly')]
        [string] $MemberFilter,

        [parameter(position=2, parametersetname='optionallyqualifiedmembersonly')]
        [parameter(position=2, parametersetname='fullyqualifiedmembersonly')]
        [parameter(parametersetname='urimembersonly')]
        [ValidateSet('Property', 'Relationship', 'Method')]
        [string] $MemberType,

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

        $isFullyQualified = $FullyQualifiedTypeName.IsPresent -or ( $TypeName -and ( $TypeClass -ne 'Primitive' -and $TypeName.Contains('.') ) )

        $targetTypeName = if ( $TypeName ) {
            $TypeName
        } else {
            $uriInfo = Get-GraphUriInfo $Uri -GraphScope $targetContext.Name -erroraction stop
            $isFullyQualified = $true
            if ( $uriInfo.FullTypeName -eq 'Null' ) {
                return $null
            }
            $uriInfo.FullTypeName
        }

        $type = $typeManager |=> FindTypeDefinition $remappedTypeClass $targetTypeName $isFullyQualified ( $TypeClass -ne 'Any' )

        if ( ! $type ) {
            if ( $TypeName ) {
                throw "The specified type '$TypeName' of type class '$TypeClass' was not found in graph '$($targetContext.name)'"
            } else {
                throw "Unexpected error: the specified URI '$Uri' could nnot be resolved to any type in graph '$($targetContext.name)'"
            }
        }

        $result = $::.TypeHelper |=> ToPublic $type

        if ( ! $TransitiveMembers.IsPresent ) {
            $result | sort-object name
        } else {
            $fieldMap = [ordered] @{
                Property = 'Properties'
                Relationship = 'Relationships'
                Method = 'Methods'
            }

            $orderedMemberFields = if ( $MemberType ) {
                , $fieldMap[$MemberType]
            } else {
                $fieldMap.values
            }

            foreach ( $memberField in $orderedMemberFields ) {
                $members = if ( ! $MemberFilter ) {
                    $result.$MemberField
                } else {
                    $result.$MemberField | where { $_.Name -like "*$($MemberFilter)*" }
                }

                $members | sort-object name
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
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphType Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
