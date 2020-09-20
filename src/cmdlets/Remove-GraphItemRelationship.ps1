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
. (import-script common/TypeUriParameterCompleter)
. (import-script common/GraphUriParameterCompleter)

function Remove-GraphItemRelationship {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='uriandpropertytouri')]
    param(
        [parameter(position=0, parametersetname='uriandpropertytoid', mandatory=$true)]
        [parameter(position=0, parametersetname='uriandpropertytouri', mandatory=$true)]
        [parameter(position=0, parametersetname='uriandpropertytoobject', mandatory=$true)]
        [Alias('FromUri')]
        [Uri] $Uri,

        [Alias('WithRelationship')]
        [parameter(position=1)]
        [string] $Relationship,

        [parameter(parametersetname='typeandpropertytoid', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytouri', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytoobject', mandatory=$true)]
        [Alias('FromType')]
        [string] $TypeName,

        [parameter(parametersetname='typeandpropertytoid', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytouri', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytoobject', mandatory=$true)]
        [Alias('FromId')]
        [string] $Id,

        [parameter(position=0, parametersetname='typedobjectandpropertytoid', mandatory=$true)]
        [parameter(position=0, parametersetname='typedobjectandpropertytouri', mandatory=$true)]
        [parameter(position=0, parametersetname='typedobjectandpropertytoobject', mandatory=$true)]
        [Alias('FromItem')]
        [PSCustomObject] $GraphItem,

        [string] $OverrideTargetTypeName,

        [Alias('ToId')]
        [parameter(parametersetname='typedobjectandpropertytoid', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytoid', mandatory=$true)]
        [parameter(parametersetname='uriandpropertytoid', mandatory=$true)]
        [string] $TargetId,

        [parameter(parametersetname='uriandpropertytoobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertytoobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='typeandpropertytoobject', valuefrompipeline=$true, mandatory=$true)]
        [Alias('ToItem')]
        [PSCustomObject] $TargetObject,

        [parameter(parametersetname='uriandpropertytouri', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('ToUri')]
        [Alias('GraphUri')]
        [Uri[]] $TargetUri,

        [parameter(parametersetname='uriandpropertytoid')]
        [parameter(parametersetname='typeandpropertytoid')]
        [parameter(parametersetname='typedobjectandpropertytoid')]
        [parameter(parametersetname='uriandpropertytouri', valuefrompipelinebypropertyname=$true)]
        [parameter(parametersetname='typeandpropertytouri', valuefrompipelinebypropertyname=$true)]
        [parameter(parametersetname='typedobjectandpropertytouri', valuefrompipelinebypropertyname=$true)]
        [parameter(parametersetname='uriandpropertytoobject')]
        [parameter(parametersetname='typeandpropertytoobject')]
        [parameter(parametersetname='typedobjectandpropertytoobject')]
        $GraphName,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipRelationshipCheck
    )
    begin {
        Enable-ScriptClassVerbosePreference

        $sourceInfo = $::.TypeUriHelper |=> GetReferenceSourceInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Id $Uri $GraphItem $Relationship

        if ( ! $sourceInfo ) {
            throw "Unable to determine Uri for specified GraphItem parameter -- specify the TypeName or Uri parameter and retry the command"
        }

        if ( ! $SkipRelationshipCheck.IsPresent ) {
            $::.QueryTranslationHelper |=> ValidatePropertyProjection $sourceInfo.RequestInfo.Context $sourceInfo.RequestInfo.TypeInfo $Relationship NavigationProperty
        }

        $targetTypeInfo = $::.TypeUriHelper |=> GetReferenceTargetTypeInfo $GraphName $sourceInfo.RequestInfo $Relationship $OverrideTargetTypeName $false

        if ( ! $targetTypeInfo ) {
            throw "Unable to find specified property '$Relationship' on the specified source -- specify the property's type with the OverrideTargetTypeName and retry the command"
        }

        $targetTypeName = $targetTypeInfo.TypeId

        $referenceUris = @()
    }

    process {
        $targetInfo = $::.TypeUriHelper |=> GetReferenceTargetInfo $GraphName $targetTypeName $FullyQualifiedTypeName.IsPresent $targetId $TargetUri $TargetObject

        if ( ! $targetInfo ) {
            throw "Unable to determine URI for specified type '$targetTypeName' or input object"
        }

        $graphNameParameter = @{}

        if ( $graphName ) {
            $graphNameParameter = @{GraphName=$GraphName}
        }

        $referenceId = $targetInfo.Uri.tostring().trimend('/') -split '/' | select -last 1

        $referenceUri = $sourceInfo.Uri, $referenceId, '$ref' -join '/'

        $referenceUris += $referenceUri
    }

    end {
        foreach ( $referenceUriToRemove in $referenceUris ) {
            Invoke-GraphRequest $referenceUriToRemove -Method DELETE -connection $sourceInfo.RequestInfo.Context.connection | out-null
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship Property (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship Uri (new-so GraphUriParameterCompleter LocationUri)
