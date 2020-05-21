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
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='typeandpropertytotargetobject')]
    param(
        [parameter(position=0, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertytotargetobject', mandatory=$true)]
        [Alias('FromType')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=1, parametersetname='typeandpropertytotargetobject', mandatory=$true)]
        [Alias('FromId')]
        [string] $Id,

        [parameter(position=0, parametersetname='typedobjectandpropertytotargetid', mandatory=$true)]
        [parameter(position=0, parametersetname='typedobjectandpropertytotargetobject', mandatory=$true)]
        [Alias('FromItem')]
        [PSCustomObject] $GraphItem,

        [parameter(position=2, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=2, parametersetname='typeandpropertytotargetobject', mandatory=$true)]
        [parameter(position=1, parametersetname='typedobjectandpropertytotargetid', mandatory=$true)]
        [parameter(position=1, parametersetname='typedobjectandpropertytotargetobject', mandatory=$true)]
        [parameter(position=1, parametersetname='uriandpropertytotargetid')]
        [parameter(position=1, parametersetname='uriandpropertytotargetobject')]
        [parameter(position=1, parametersetname='uriandpropertytotargeturi')]
        [string] $Relationship,

        [parameter(parametersetname='typeandpropertytotargetid')]
        [parameter(parametersetname='typedobjectandpropertytotargetid')]
        [parameter(parametersetname='uriandpropertytotargetid')]
        [parameter(parametersetname='typedobjectandpropertytotargetobject')]
        [string] $OverrideTargetTypeName,

        [parameter(position=3, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=2, parametersetname='typedobjectandpropertytotargetid', mandatory=$true)]
        [parameter(position=2, parametersetname='uriandpropertytotargetid', mandatory=$true)]
        [Alias('ToId')]
        [object[]] $TargetId,

        [parameter(parametersetname='typeandpropertytotargetobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertytotargetobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='uriandpropertytotargetobject', valuefrompipeline=$true, mandatory=$true)]
        [Alias('ToItem')]
        [object] $TargetObject,

        [parameter(parametersetname='uriandpropertytotargeturi', mandatory=$true)]
        [parameter(parametersetname='uriandpropertytotargetid', mandatory=$true)]
        [parameter(parametersetname='uriandpropertytotargetobject', mandatory=$true)]
        [Alias('FromUri')]
        [Uri] $Uri,

        [parameter(parametersetname='uriandpropertytotargeturi', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytotargeturi', mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertytotargeturi', mandatory=$true)]
        [Alias('ToUri')]
        [Uri[]] $TargetUri,

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
    }

    process {
        $targetInfo = $::.TypeUriHelper |=> GetReferenceTargetInfo $GraphName $targetTypeName $FullyQualifiedTypeName.IsPresent $targetId $TargetUri $TargetObject

        $graphNameParameter = @{}

        if ( $graphName ) {
            $graphNameParameter = @{GraphName=$GraphName}
        }

        $referenceId = $targetInfo.Uri.tostring().trimend('/') -split '/' | select -last 1

        $referenceUri = $sourceInfo.Uri, $referenceId, '$ref' -join '/'

        Invoke-GraphRequest $referenceUri -Method DELETE -connection $sourceInfo.RequestInfo.Context.connection -erroraction 'stop' | out-null
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship Property (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItemRelationship Uri (new-so GraphUriParameterCompleter LocationUri)
