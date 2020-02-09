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
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/WriteOperationParameterCompleter)

function New-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='optionallyqualified')]
    param(
        [parameter(position=0, mandatory=$true)]
        [Uri] $Uri,

        [parameter(position=1, parametersetname='optionallyqualified')]
        [parameter(position=1, parametersetname='fullyqualified')]
        [string[]] $Property,

        [parameter(position=2, parametersetname='optionallyqualified')]
        [parameter(position=2, parametersetname='fullyqualified')]
        [object[]] $Value,

        [parameter(parametersetname='fromobjectoptionallyqualified', ValueFromPipeline=$true)]
        [parameter(parametersetname='fromobjectfullyqualified', ValueFromPipeline=$true)]
        [object] $GraphObject,

        [ValidateSet('POST', 'PUT')]
        [String] $Method = $null,

        $TypeName,

        $GraphName,

        [parameter(parametersetname='optionallyqualifiedproplist', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedproplist', mandatory=$true)]
        $PropertyList,

        [parameter(parametersetname='fullyqualified', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedproplist', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [switch] $Recurse,

        [switch] $SetDefaultValues,

        [switch] $SkipPropertyCheck
    )

    Enable-ScriptClassVerbosePreference

    $targetType = if ( $TypeName ) {
        $TypeName
    } else {
        $uriInfo = Get-GraphUri $Uri
        $uriInfo.FullTypeName
    }

    $newGraphObjectParameters = @{}

    @(
        'Property'
        'Value'
        'GraphObject'
        'GraphName'
        'PropertyList'
        'FullyQualifiedTypeName'
        'Recurse'
        'SetDefaultValues'
        'SkipPropertyCheck'
    ) | foreach {
        if ( $PSBoundParameters[$_] -ne $null ) {
            $newGraphObjectParameters[$_] = $PSBoundParameters[$_]
        }
    }

    $newObject = New-GraphObject -TypeName $targetType -TypeClass Entity @newGraphObjectParameters -erroraction 'stop'

    $createMethod = if ( $Method ) {
        $Method
    } else {
        if ( ( $newObject | gm Id -erroraction ignore ) -and $newObject.Id ) {
            'PUT'
        } else {
            'POST'
        }
    }

    Invoke-GraphRequest $Uri -Method $createMethod -Body $newObject -erroraction 'stop'
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem TypeName (new-so WriteOperationParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem Property (new-so WriteOperationParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem GraphName (new-so GraphParameterCompleter)
