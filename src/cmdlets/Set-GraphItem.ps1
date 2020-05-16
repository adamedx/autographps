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

function Set-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='typedobjectandpropertylist')]
    param(
        [parameter(position=0, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertymap', mandatory=$true)]
        [string] $TypeName,

        [parameter(position=1, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(position=1, parametersetname='typeandpropertymap', mandatory=$true)]
        [string] $Id,

        [parameter(position=2, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertylist', mandatory=$true)]
        [parameter(parametersetname='uriandpropertylist', mandatory=$true)]
        [string[]] $Property,

        [parameter(position=3, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertylist', mandatory=$true)]
        [parameter(parametersetname='uriandpropertylist', mandatory=$true)]
        [object[]] $Value,

        [parameter(parametersetname='typedobjectandpropertylist', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertymap', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem,

        [parameter(parametersetname='uriandpropertylist', mandatory=$true)]
        [parameter(parametersetname='uriandpropertymap', mandatory=$true)]
        [Uri] $Uri,

        [string] $GraphName,

        [parameter(position=2, parametersetname='typeandpropertymap', mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertymap', mandatory=$true)]
        [parameter(position=0, parametersetname='uriandpropertymap', mandatory=$true)]
        [HashTable] $PropertyMap,

        [switch] $FullyQualifiedTypeName,

        [switch] $Recurse,

        [switch] $SetDefaultValues,

        [switch] $SkipPropertyCheck
    )

    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        } elseif ( $GraphItem -and ( $GraphItem | gm -membertype noteproperty id -erroraction ignore ) ) {
            $GraphItem.Id # This is needed when an object is supplied without an id parameter
        }

        $writeRequestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphItem

        $newGraphObjectParameters = @{}

        @(
            'Property'
            'Value'
            'GraphName'
            'PropertyMap'
            'FullyQualifiedTypeName'
            'Recurse'
            'SetDefaultValues'
            'SkipPropertyCheck'
        ) | foreach {
            if ( $PSBoundParameters[$_] -ne $null ) {
                $newGraphObjectParameters[$_] = $PSBoundParameters[$_]
            }
        }

        if ( $GraphItem -and ! $writeRequestInfo.Uri ) {
            throw "Unable to determine Uri for specified GraphItem parameter -- specify the TypeName or Uri parameter and retry the command"
        }

        $newObject = if ( $writeRequestInfo.TypeName ) {
            New-GraphObject -TypeName $writeRequestInfo.TypeName -TypeClass Entity @newGraphObjectParameters -erroraction 'stop'
        } elseif ( $propertyMap ) {
            $propertyMap
        } else {
            throw "Object type is ambiguous -- specify the PropertyMap parameter and try again"
        }

        Invoke-GraphRequest $writeRequestInfo.Uri -Method PATCH -Body $newObject -connection $writeRequestInfo.Context.connection -erroraction 'stop'
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem Property (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem GraphName (new-so GraphParameterCompleter)
