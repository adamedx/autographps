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
. (import-script common/TypeUriHelper)
. (import-script common/RelationshipDisplayType)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeUriParameterCompleter)
. (import-script common/GraphUriParameterCompleter)

function Get-GraphItemRelationship {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='uriandproperty')]
    param(
        [parameter(position=0, parametersetname='uriandproperty', mandatory=$true)]
        [parameter(parametersetname='uripipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('FromUri')]
        [Alias('GraphUri')]
        [Uri] $Uri,

        [Alias('WithRelationship')]
        [parameter(position=1)]
        [string[]] $Relationship,

        [parameter(parametersetname='typeandproperty', mandatory=$true)]
        [Alias('FromType')]
        [string] $TypeName,

        [parameter(parametersetname='typeandproperty', mandatory=$true)]
        [Alias('FromId')]
        [string] $Id,

        [parameter(parametersetname='typedobjectandproperty', valuefrompipeline=$true, mandatory=$true)]
        [Alias('FromItem')]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [parameter(parametersetname='uripipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='uriandproperty')]
        [parameter(parametersetname='typeandproperty')]
        [string] $GraphName,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipRelationshipCheck
    )
    begin {
        Enable-ScriptClassVerbosePreference

        $relationshipInfo = $null
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphItem $true

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

        $relationshipInfo = foreach ( $currentRelationship in $targetRelationships ) {
            if ( ! $SkipRelationshipCheck.IsPresent ) {
                $::.QueryTranslationHelper |=> ValidatePropertyProjection $requestInfo.Context $requestInfo.TypeInfo $currentRelationship NavigationProperty
            }

            $fromUri = $requestInfo.Uri
            $relationshipRequestUri = [Uri] ( $::.GraphUtilities |=> ToLocationUriPath $requestInfo.context ( $requestInfo.Uri.ToString(), $currentRelationship -join '/' ) )

            @{Name=$currentRelationShip; FromUri=$fromUri; RequestUri=$relationshipRequestUri}
        }
    }

    end {
        $graphNameArgument = if ( $GraphName ) { @{GraphName=$GraphName} } else { @{} }

        $relationshipResults = foreach ( $relationshipDetail in $relationshipInfo ) {
            $relatedItems = $relationshipDetail.RequestUri | Get-GraphResourceWithMetadata @graphNameArgument -ErrorAction $requestErrorAction -Property id

            @{
                RelationshipInfo = $relationshipDetail
                RelatedItems = $relatedItems
            }
        }

        foreach ( $result in $relationshipResults ) {
            foreach ( $relatedItem in $result.RelatedItems ) {
                $relatedItemUri = ( $relatedItem | Get-GraphUri -UnqualifiedUri  -erroraction silentlycontinue )[0]
                new-so RelationshipDisplayType $requestInfo.Context.Name $result.RelationshipInfo.Name $result.RelationshipInfo.FromUri $relatedItemUri $relatedItem.id
            }
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship Uri (new-so GraphUriParameterCompleter LocationUri)
