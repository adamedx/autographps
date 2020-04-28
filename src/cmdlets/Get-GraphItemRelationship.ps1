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

function Get-GraphItemRelationship {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='typedobjectandproperty')]
    param(
        [parameter(position=0, parametersetname='typeandproperty', mandatory=$true)]
        [Alias('FromType')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='typeandproperty', mandatory=$true)]
        [Alias('FromId')]
        [string] $Id,

        [parameter(parametersetname='typedobjectandproperty', valuefrompipeline=$true, mandatory=$true)]
        [Alias('FromObject')]
        [PSCustomObject] $GraphObject,

        [Alias('ByRelationshipProperty')]
        [parameter(mandatory=$true)]
        [string] $Relationship,

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

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphObject

        if ( ! $SkipRelationshipCheck.IsPresent ) {
            $::.QueryTranslationHelper |=> ValidatePropertyProjection $requestInfo.Context $requestInfo.TypeInfo $Relationship NavigationProperty
        }

        $relationShipUri = $requestInfo.Uri.ToString(), $Relationship -join '/'

        Get-GraphResourceWithMetadata -Uri $relationShipUri -GraphName $GraphName -ContentOnly:$($ContentOnly.IsPresent)
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemRelationship Uri (new-so GraphUriParameterCompleter LocationUri)
