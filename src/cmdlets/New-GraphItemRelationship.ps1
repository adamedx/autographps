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

function New-GraphItemRelationship {
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

        $sourceInfo = $::.TypeUriHelper |=> GetReferenceSourceInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Id $Uri $GraphItem $Relationship $false

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

        $fromUri = $sourceInfo.uri.tostring().trimend('/'), '$ref' -join '/'

        # Note that if the array has only one element, it will be treated like a single
        # element, rather than an array. Normally, this automatic behavior is quite undesirable,
        # but in this case it makes it slightly easier by letting us accumulate results in an array
        # in both the case where we are posting to a collection and also when we are not.
        $references = @()
    }

    process {
        $targetInfo = if ( $TargetUri ) {
            foreach ( $destinationUri in $TargetUri ) {
                $::.TypeUriHelper |=> GetReferenceTargetInfo $GraphName $targetTypeName $FullyQualifiedTypeName.IsPresent $TargetId $destinationUri $null
            }
        } elseif ( $TargetObject ) {
            $requestInfo = $::.TypeUriHelper |=> GetReferenceTargetInfo $GraphName $targetTypeName $FullyQualifiedTypeName.IsPresent $TargetId $TargetUri $TargetObject
            if ( ! $requestInfo.Uri ) {
                throw "An object specified for the 'TargetObject' parameter does not have an Id field; specify the object's URI or the OverrideTargetTypeName and TargetId parameters and retry the command"
            }
            $requestInfo
        } else {
            foreach ( $destinationId in $TargetId ) {
                $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $targetTypeName $FullyQualifiedTypeName.IsPresent $null $destinationId $null
            }
        }

        foreach ( $target in $targetInfo ) {
            $absoluteUri = $::.TypeUriHelper |=> ToGraphAbsoluteUri $target.Context $target.Uri
            $references += @{'@odata.id' = $absoluteUri}
        }
    }

    end {
        foreach ( $referenceRequest in $references ) {
            Invoke-GraphRequest $fromUri -Method POST -Body $referenceRequest -connection $sourceInfo.RequestInfo.Context.connection -version $sourceInfo.RequestInfo.Context.Version -erroraction 'stop' | out-null
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItemRelationship TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItemRelationship Property (new-so TypeUriParameterCompleter Property $true NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItemRelationship OverrideTargetTypeName (new-so TypeUriParameterCompleter TypeName $true OverrideTargetTypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItemRelationship GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItemRelationship Uri (new-so GraphUriParameterCompleter LocationUri)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItemRelationship TargetUri (new-so GraphUriParameterCompleter LocationUri)
