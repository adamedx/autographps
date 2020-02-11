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
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='bytypeoptionallyqualified')]
    param(
        [parameter(position=0, parametersetname='bytypeoptionallyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeoptionallyqualifiedproplist', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualifiedproplist', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeoptionallyqualifiedfromobject', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeoptionallyqualified')]
        [parameter(position=1, parametersetname='bytypefullyqualified')]
        [parameter(position=1, parametersetname='byuri')]
        [string[]] $Property,

        [parameter(position=2, parametersetname='bytypeoptionallyqualified')]
        [parameter(position=2, parametersetname='bytypefullyqualified')]
        [parameter(position=2, parametersetname='byuri')]
        [object[]] $Value,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuriproplist')]
        [parameter(parametersetname='byurifromobject')]
        [Uri] $Uri,

        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [object] $GraphObject,

        [ValidateSet('POST', 'PUT')]
        [String] $Method = $null,

        $GraphName,

        [parameter(parametersetname='bytypeoptionallyqualifiedproplist', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedproplist', mandatory=$true)]
        [parameter(parametersetname='byuriproplist', mandatory=$true)]
        $PropertyList,

        [parameter(parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedproplist', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [switch] $Recurse,

        [switch] $SetDefaultValues,

        [switch] $SkipPropertyCheck
    )

    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        $writeRequestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $GraphObject

        $newGraphObjectParameters = @{}

        @(
            'Property'
            'Value'
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

        $newObject = if ( $GraphObject ) {
            $GraphObject
        } else {
            New-GraphObject -TypeName $writeRequestInfo.TypeName -TypeClass Entity @newGraphObjectParameters -erroraction 'stop'
        }

        $createMethod = if ( $Method ) {
            $Method
        } else {
            if ( ( $newObject | gm Id -erroraction ignore ) -and $newObject.Id ) {
                'PUT'
            } else {
                'POST'
            }
        }

        Invoke-GraphRequest $writeRequestInfo.Uri -Method $createMethod -Body $newObject -connection $writeRequestInfo.Context.connection -erroraction 'stop'
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem TypeName (new-so WriteOperationParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem Property (new-so WriteOperationParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem GraphName (new-so GraphParameterCompleter)
