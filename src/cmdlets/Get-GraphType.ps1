# Copyright 2021, Adam Edwards
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
    [cmdletbinding(positionalbinding=$false)]
    [OutputType('GraphTypeDisplayType')]
    param(
        [parameter(position=0, parametersetname='optionallyqualified', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=0, parametersetname='fullyqualified', mandatory=$true)]
        [Alias('TypeId')]
        [Alias('FullTypeName')]
        $TypeName,

        [parameter(parametersetname='optionallyqualified', valuefrompipelinebypropertyname=$true)]
        [parameter(parametersetname='fullyqualified')]
        [parameter(parametersetname='list')]
        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        $TypeClass = 'Any',

        [parameter(parametersetname='optionallyqualified')]
        $Namespace,

        [parameter(parametersetname='uri', mandatory=$true)]
        $Uri,

        [parameter(parametersetname='forobject', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [parameter(valuefrompipelinebypropertyname=$true)]
        $GraphName,

        [parameter(parametersetname='fullyqualified', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [parameter(parametersetname='list', mandatory=$true)]
        [switch] $ListNames
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName
    }

    process {
        if ( ! $ListNames.IsPresent ) {
            $remappedTypeClass = if ( $TypeClass -ne 'Any' ) {
                $TypeClass
            } else {
                'Unknown'
            }

            $isFullyQualified = $FullyQualifiedTypeName.IsPresent -or ($GraphItem -ne $null) -or ( $TypeName -and ( $TypeClass -ne 'Primitive' -and $TypeName.Contains('.') ) )

            $typeManager = $::.TypeManager |=> Get $targetContext

            $targetTypeName = if ( $TypeName ) {
                $TypeName
            } elseif ( $GraphItem ) {
                $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $null $null $false $null $null $GraphItem
                $requestInfo.TypeInfo.FullTypeName
            } else {
                $uriInfo = Get-GraphUriInfo $Uri -GraphName $targetContext.Name -erroraction stop
                $isFullyQualified = $true
                if ( $uriInfo.FullTypeName -eq 'Null' ) {
                    return $null
                }
                $uriInfo.FullTypeName
            }

            $type = $typeManager |=> FindTypeDefinition $remappedTypeClass $targetTypeName $isFullyQualified

            if ( ! $type ) {
                if ( $TypeName ) {
                    throw "The specified type '$TypeName' of type class '$TypeClass' was not found in graph '$($targetContext.name)'"
                } else {
                    throw "Unexpected error: the specified URI '$Uri' could not be resolved to any type in graph '$($targetContext.name)'"
                }
            }

            $defaultUri = if ( $type.Class -eq 'Entity' ) {
                $::.TypeUriHelper |=> DefaultUriForType $targetContext $type.TypeId
            }

            $result = $::.TypeHelper |=> ToPublic $type $defaultUri $targetContext.Name

            $result | sort-object name
        }
    }

    end {
        if ( $ListNames.IsPresent ) {
            $sortTypeClass = if ( $TypeClass -ne 'Any' ) {
                $TypeClass
            } else {
                'Entity'
            }
            $::.TypeManager |=> GetSortedTypeNames $sortTypeClass $targetContext
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphType TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphType GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphType Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
