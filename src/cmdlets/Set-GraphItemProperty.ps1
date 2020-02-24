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

function Set-GraphItemProperty {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='typedobjectandpropertylist')]
    param(
        [parameter(position=0, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertymap', mandatory=$true)]
        $TypeName,

        [parameter(parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(parametersetname='typeandpropertymap', mandatory=$true)]
        $Id,

        [parameter(position=1, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(position=0, parametersetname='typedobjectandpropertylist', mandatory=$true)]
        [parameter(position=1, parametersetname='uriandpropertylist', mandatory=$true)]
        [string[]] $Property,

        [parameter(position=2, parametersetname='typeandpropertylist', mandatory=$true)]
        [parameter(position=1, parametersetname='typedobjectandpropertylist', mandatory=$true)]
        [parameter(position=2, parametersetname='uriandpropertylist', mandatory=$true)]
        [object[]] $Value,

        [parameter(parametersetname='typedobjectandpropertylist', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertymap', valuefrompipeline=$true, mandatory=$true)]
        [object] $GraphObject,

        [parameter(parametersetname='uriandpropertylist', mandatory=$true)]
        [parameter(parametersetname='uriandpropertymap', mandatory=$true)]
        [Uri] $Uri,

        $GraphName,

        [parameter(parametersetname='typeandpropertymap', mandatory=$true)]
        [parameter(parametersetname='typedobjectandpropertymap', mandatory=$true)]
        [parameter(parametersetname='uriandpropertymap', mandatory=$true)]
        $PropertyMap,

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
        } elseif ( $GraphObject -and ( $GraphObject | gm -membertype noteproperty id -erroraction ignore ) ) {
            $GraphObject.Id # This is needed when an object is supplied without an id parameter
        }

        $writeRequestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphObject

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

        if ( $GraphObject -and ! $writeRequestInfo.Uri ) {
            throw "Unable to determine Uri for specified GraphObject parameter -- specify the TypeName or Uri parameter and retry the command"
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

$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItemProperty TypeName (new-so WriteOperationParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItemProperty Property (new-so WriteOperationParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItemProperty GraphName (new-so GraphParameterCompleter)
