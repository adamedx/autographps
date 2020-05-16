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

function Get-GraphItemUri {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='fromtype')]
    param(
        [parameter(position=0, parametersetname='fromtype', mandatory=$true)]
        [parameter(position=0, parametersetname='fromtypeandid', mandatory=$true)]
        [parameter(position=0, parametersetname='fromtypeandidrelationship', mandatory=$true)]
        [Alias('FromType')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='fromtypeandid', mandatory=$true)]
        [parameter(position=1, parametersetname='fromtypeandidrelationship', mandatory=$true)]
        [Alias('FromId')]
        [string] $Id,

        [parameter(parametersetname='fromUriAndRelationship', mandatory=$true)]
        [parameter(parametersetname='fromtypeandidrelationship', mandatory=$true)]
        [parameter(parametersetname='fromObjectAndRelationship', mandatory=$true)]
        [Alias('WithRelationship')]
        [string[]] $Relationship,

        [parameter(parametersetname='fromUriAndRelationship')]
        [parameter(parametersetname='fromtypeandidrelationship')]
        [parameter(parametersetname='fromObjectAndRelationship')]
        [Alias('WithRelatedItemId')]
        [string] $RelatedItemId,

        [parameter(parametersetname='fromObject', mandatory=$true)]
        [parameter(parametersetname='fromObjectAndRelationship', mandatory=$true)]
        [PSCustomObject] $FromObject,

        [string] $OverrideRelatedItemType,

        [parameter(parametersetname='fromUri', mandatory=$true)]
        [parameter(parametersetname='fromUriAndRelationship', mandatory=$true)]
        [Alias('FromUri')]
        [Uri] $Uri,

        [string] $GraphName,

        [switch] $FullyQualifiedTypeName,

        [switch] $AbsoluteUri,

        [switch] $SkipPropertyCheck
    )

    Enable-ScriptClassVerbosePreference

    $targetId = if ( $Id ) {
        $Id
    } elseif ( $FromObject -and ( $FromObject | gm -membertype noteproperty id -erroraction ignore ) ) {
        $FromObject.Id # This is needed when an object is supplied without an id parameter
    }

    $referenceInfo = $::.TypeUriHelper |=> GetReferenceSourceInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Id $Uri $FromObject $Relationship

    if ( ! $referenceInfo -or ( $FromObject -and ! $referenceInfo.requestInfo.Uri ) ) {
        throw "Unable to determine Uri for specified FromObject parameter -- specify the correct TypeName or Uri parameter and retry the command"
    }

    $graphScopeParameter = @{}

    if ( $GraphName ) {
        $graphScopeParameter = @{GraphScope=$GraphName}
    }

    try {
        Get-GraphUriInfo $referenceInfo.RequestInfo.Uri.tostring() @graphScopeParameter | out-null
    } catch {
        throw 'Unable to resolve specified parameters to a valid URI for the graph'
    }

    if ( ( $Uri -or $FromObject) -and $Relationship ) {
        $uriTypeClass = $referenceInfo.RequestInfo.TypeInfo.UriInfo.Class
        $sourceUri = $referenceInfo.RequestInfo.Uri
        if ( $uriTypeClass -ne 'EntityType' -and $uriTypeClass -ne 'Singleton' ) {
            throw "The relationship '$Relationship' was specified, but the specified object or URI resolving to URI '$sourceUri' is of type class '$uriTypeClass' and therefore is not a valid target for any relationship."
        }
    }

    $resultUri = if ( $RelatedItemId ) {
        $targetTypeInfo = $::.TypeUriHelper |=> GetReferenceTargetTypeInfo $GraphName $referenceInfo.RequestInfo $Relationship $OverrideRelatedItemType

        if ( ! $targetTypeInfo ) {
            throw "Unable to find type information for relationship '$Relationship' and specified parameters"
        }

        $targetInfo = $::.TypeUriHelper |=> GetReferenceTargetInfo $GraphName $targetTypeInfo.TypeId $FullyQualifiedTypeName.IsPresent $relatedItemId $referenceInfo.Uri $null $false

        $referenceInfo.Uri.tostring(), $RelatedItemId -join '/'
    } elseif ( $FromObject )  {
        $targetTypeInfo = $::.TypeUriHelper |=> GetReferenceTargetTypeInfo $GraphName $referenceInfo.RequestInfo $Relationship $OverrideRelatedItemType
        $targetInfo = $::.TypeUriHelper |=> GetReferenceTargetInfo $GraphName $targetTypeInfo.TypeId $FullyQualifiedTypeName.IsPresent $relatedItemId $referenceInfo.Uri $null $false

        $referenceInfo.Uri.tostring()
    } else{
        $referenceInfo.Uri.tostring()
    }

    if ( ! $AbsoluteUri.IsPresent ) {
        $resultUri
    } else {
        ($::.TypeUriHelper |=> ToGraphAbsoluteUri $referenceInfo.requestInfo.Context $resultUri).tostring()
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemUri TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemUri Relationship (new-so TypeUriParameterCompleter Property $true NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemUri GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItemUri Uri (new-so GraphUriParameterCompleter LocationUri)
