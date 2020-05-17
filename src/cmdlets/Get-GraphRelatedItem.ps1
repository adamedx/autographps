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
. (import-script common/TypeUriHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)
. (import-script common/GraphUriParameterCompleter)

function Get-GraphRelatedItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='typedobjectandproperty')]
    param(
        [parameter(position=0, parametersetname='typeandproperty', mandatory=$true)]
        [Alias('FromType')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='typeandproperty', mandatory=$true)]
        [Alias('FromId')]
        [string] $Id,

        [parameter(parametersetname='typedobjectandproperty', valuefrompipeline=$true, mandatory=$true)]
        [Alias('FromItem')]
        [PSCustomObject] $GraphItem,

        [Alias('WithRelationship')]
        [string[]] $Relationship,

        [parameter(parametersetname='uriandproperty', mandatory=$true)]
        [Alias('FromUri')]
        [Uri] $Uri,

        $GraphName,

        [switch] $ContentOnly,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipRelationshipCheck
    )
    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphItem

        $requestErrorAction = $ErrorActionPreference

        $targetRelationships = if ( $Relationship -and ! ( $Relationship -is [string] -and $Relationship.Contains('*') ) ) {
            $Relationship
        } else {
            if ( ! $PSBoundParameters['ErrorActionPreference'] ) {
                $requestErrorAction = 'SilentlyContinue'
            }
            $typeManager = $::.TypeManager |=> Get $requestInfo.Context
            $typeDefinition = $typeManager |=> GetTypeDefinition Entity $requestInfo.TypeName
            $relationships = $typeManager |=> GetTypeDefinitionTransitiveProperties $typeDefinition NavigationProperty

            $relationshipProperties = if ( $Relationship ) {
                $relationships | where { $_ -like $relationship }
            } else {
                $relationships
            }

            if ( $relationshipProperties ) {
                $relationshipProperties | select -expandproperty Name
            }
        }

        $relationShipUris = foreach ( $currentRelationship in $targetRelationships ) {
            if ( ! $SkipRelationshipCheck.IsPresent ) {
                $::.QueryTranslationHelper |=> ValidatePropertyProjection $requestInfo.Context $requestInfo.TypeInfo $currentRelationship NavigationProperty
            }

            $requestInfo.Uri.ToString(), $currentRelationship -join '/'
        }
    }

    end {
        $relationshipUris | Get-GraphResourceWithMetadata -GraphName $GraphName -ContentOnly:$($ContentOnly.IsPresent) -ErrorAction $requestErrorAction
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem Relationship (new-so TypeUriParameterCompleter Property $true NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem Uri (new-so GraphUriParameterCompleter LocationUri)
