# Copyright 2023, Adam Edwards
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

        [Alias('Property')]
        [String[]] $Select = $null,

        [parameter(parametersetname='uripipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='uriandproperty')]
        [parameter(parametersetname='typeandproperty')]
        [parameter(parametersetname='typedobjectandproperty')]
        $GraphName,

        [ValidateSet('Auto', 'Default', 'Session', 'Eventual')]
        [string] $ConsistencyLevel = 'Auto',

        [switch] $Count,

        [int32] $First,

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
        } elseif ( $GraphItem -and ( $GraphItem | get-member id -erroraction ignore ) ) {
            $GraphItem.Id
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

        $relationShipUris = foreach ( $currentRelationship in $targetRelationships ) {
            if ( ! $SkipRelationshipCheck.IsPresent ) {
                $::.QueryTranslationHelper |=> ValidatePropertyProjection $requestInfo.Context $requestInfo.TypeInfo $currentRelationship NavigationProperty
            }

            [Uri] ( $::.GraphUtilities |=> ToLocationUriPath $requestInfo.context ( $requestInfo.Uri.ToString(), $currentRelationship -join '/' ) )
        }
    }

    end {
        $variableArguments = @{ConsistencyLevel=$ConsistencyLevel;Count=$Count}
        if ( $GraphName ) { $variableArguments.Add('GraphName', $GraphName) }
        if ( $First ) { $variableArguments.Add('First', $First) }
        if ( $Select ) {
            $variableArguments.Add('Select', $Select)
        }
        $relationshipUris | Get-GraphResourceWithMetadata @variableArguments -ContentOnly:$($ContentOnly.IsPresent) -All -ErrorAction $requestErrorAction
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem Select (new-so TypeUriParameterCompleter Property $false Property TypeName RelationShip )
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphRelatedItem Uri (new-so GraphUriParameterCompleter LocationUri)
