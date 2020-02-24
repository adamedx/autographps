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
. (import-script common/WriteOperationParameterCompleter)
. (import-script common/GraphUriParameterCompleter)

function Add-GraphItemReference {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='typeandpropertytotargetid')]
    param(
        [parameter(position=0, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertytotargetobject', mandatory=$true)]
        [Alias('FromType')]
        $TypeName,

        [parameter(parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(parametersetname='typeandpropertytotargetobject', mandatory=$true)]
        [Alias('FromId')]
        $Id,

        [parameter(position=0, parametersetname='typedobjectandpropertytotargetid', mandatory=$true)]
        [parameter(position=0, parametersetname='typedobjectandpropertytotargetobject', mandatory=$true)]
        [Alias('FromObject')]
        [object] $GraphObject,

        [parameter(position=1, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=1, parametersetname='typeandpropertytotargetobject', mandatory=$true)]
        [parameter(position=1, parametersetname='typedobjectandpropertytotargetid', mandatory=$true)]
        [parameter(position=1, parametersetname='typedobjectandpropertytotargetobject', mandatory=$true)]
        [parameter(position=1, parametersetname='uriandpropertytotargetid')]
        [parameter(position=1, parametersetname='uriandpropertytotargetobject')]
        [parameter(position=1, parametersetname='uriandpropertytotargeturi')]
        [string] $Property,

        [parameter(parametersetname='typeandpropertytotargetid')]
        [parameter(parametersetname='typedobjectandpropertytotargetid')]
        [parameter(parametersetname='uriandpropertytotargetid')]
        [parameter(parametersetname='typedobjectandpropertytotargetobject')]
        [string] $OverrideTargetTypeName,

        [parameter(parametersetname='typeandpropertytotargetid')]
        [parameter(parametersetname='typedobjectandpropertytotargetid')]
        [parameter(parametersetname='uriandpropertytotargetid')]
        [parameter(parametersetname='uriandpropertytotargeturi')]
        [parameter(parametersetname='typedobjectandpropertytotargetobject')]
        [ValidateSet('Auto', 'SeparateRequest', 'SharedRequest')]
        [string] $RequestOptimizationMode = 'SeparateRequest',

        [parameter(position=2, parametersetname='typeandpropertytotargetid', mandatory=$true)]
        [parameter(position=2, parametersetname='typedobjectandpropertytotargetid', mandatory=$true)]
        [parameter(position=2, parametersetname='uriandpropertytotargetid', mandatory=$true)]
        [Alias('ToId')]
        [object[]] $TargetId,

        [parameter(parametersetname='typeandpropertytotargetbject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertytotargetobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='uriandpropertytotargetobject', valuefrompipeline=$true, mandatory=$true)]
        [Alias('ToObject')]
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

        [switch] $FullyQualifiedTypeName
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $fromId = if ( $Id ) {
            $Id
        } elseif ( $GraphObject -and ( $GraphObject | gm -membertype noteproperty id -erroraction ignore ) ) {
            $GraphObject.Id # This is needed when an object is supplied without an id parameter
        }

        $writeRequestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $fromId $GraphObject

        if ( $GraphObject -and ! $writeRequestInfo.Uri ) {
            throw "Unable to determine Uri for specified GraphObject parameter -- specify the TypeName or Uri parameter and retry the command"
        }

        $targetAsCollection = $RequestOptimizationMode -eq 'SharedRequest'
        $targetTypeName = $OverrideTargetTypeName

        if ( $Property ) {
            $targetPropertyInfo = if ( ! $OverrideTargetTypeName -or $RequestOptimizationMode -eq 'Auto' ) {
                $targetType = Get-GraphType $writeRequestInfo.TypeName
                $targetTypeInfo = $targetType.NavigationProperties | where name -eq $Property

                if ( ! $targetTypeInfo ) {
                    throw "Unable to find specified property '$Property' on the specified source -- specify the property's type with the OverrideTargetTypeName and set the RequestOptimizationMode to a value other than 'Auto' and retry the command"
                }
                $targetTypeInfo
            }

            if ( $RequestOptimizationMode -eq 'Auto' ) {
                $targetAsCollection = $targetPropertyInfo.IsCollection
            }

            if ( ! $targetTypeName ) {
                $targetTypeName = $targetPropertyInfo.TypeId
            }
        }

        $segments = @()
        $segments += $writeRequestInfo.uri.tostring()
        if ( $Property -and $writeRequestInfo.uri ) {
            $segments += $Property
        }
        $segments += '$ref'

        $fromUri = $segments -join '/'

        # Note that if the array has only one element, it will be treated like a single
        # element, rather than an array. Normally, this automatic behavior is quite undesirable,
        # but in this case it makes it slightly easier by letting us accumulate results in an array
        # in both the case where we are posting to a collection and also when we are not.
        $references = @()
    }

    process {
        $targetInfo = if ( $TargetUri ) {
            foreach ( $destinationUri in $TargetUri ) {
                $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $destinationUri $null $null
            }
        } elseif ( $TargetObject ) {
            $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $Uri $null $TargetObject

            if ( ! $requestInfo.Uri ) {
                throw "An object specified for the 'TargetObject' parameter does not have an Id field; specify the object's URI or the TypeName and Id parameters and retry the command"
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
        $referenceRequests = $references

        if ( $targetAsCollection ) {
            $referenceRequests = , $references
        }

        foreach ( $referenceRequest in $referenceRequests ) {
            Invoke-GraphRequest $fromUri -Method POST -Body $referenceRequest -connection $writeRequestInfo.Context.connection -erroraction 'stop'
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphItemReference TypeName (new-so WriteOperationParameterCompleter TypeName TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphItemReference Property (new-so WriteOperationParameterCompleter Property TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphItemReference OverrideTargetTypeName (new-so WriteOperationParameterCompleter TypeName OverrideTargetTypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphItemReference GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphItemReference Uri (new-so GraphUriParameterCompleter LocationUri)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphItemReference TargetUri (new-so GraphUriParameterCompleter LocationUri)
